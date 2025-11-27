#!/usr/bin/env bash
# MAKER Framework - PostToolUse Hook
# Collects votes from step-executor subagents and determines winners
#
# IMPORTANT: Uses exit code 2 + stderr to reliably communicate with Claude
# (exit 0 with JSON may not be visible to Claude due to known limitations)

# Read JSON from stdin (Claude Code passes hook payload here)
json=$(cat)

# Extract relevant fields
tool_name=$(echo "$json" | jq -r '.tool_name // empty')
tool_response=$(echo "$json" | jq -r '.tool_response // empty')
session_id=$(echo "$json" | jq -r '.session_id // empty')

# Only process Task tool (subagent) responses
if [ "$tool_name" != "Task" ]; then
  exit 0
fi

# Skip if no response
if [ -z "$tool_response" ] || [ "$tool_response" = "null" ]; then
  exit 0
fi

# === RED-FLAG DETECTION ===

# Flag 1: Response too long (>2800 chars ≈ 700 tokens, per MAKER paper)
response_length=${#tool_response}
if [ "$response_length" -gt 2800 ]; then
  echo "🚩 MAKER RED FLAG: Response too long (${response_length} chars, limit: 700 tokens) - vote discarded. Spawn another step-executor with IDENTICAL input." >&2
  exit 2
fi

# Flag 2: Check for valid JSON structure in response
if ! echo "$tool_response" | jq -e '.' > /dev/null 2>&1; then
  echo "🚩 MAKER RED FLAG: Malformed JSON response - vote discarded. Spawn another step-executor with IDENTICAL input." >&2
  exit 2
fi

# Flag 3: Check for error in response
if echo "$tool_response" | jq -e '.error' > /dev/null 2>&1; then
  error_msg=$(echo "$tool_response" | jq -r '.error')
  echo "🚩 MAKER RED FLAG: Subagent error: ${error_msg} - vote discarded. Spawn another step-executor with IDENTICAL input." >&2
  exit 2
fi

# Flag 4: Schema validation - require step_id and (action OR result)
if ! echo "$tool_response" | jq -e '.step_id' > /dev/null 2>&1; then
  echo "🚩 MAKER RED FLAG: Missing required field 'step_id' - vote discarded. Spawn another step-executor with IDENTICAL input." >&2
  exit 2
fi

# Must have at least one of: action or result
has_action=$(echo "$tool_response" | jq -e '.action' > /dev/null 2>&1 && echo "yes" || echo "no")
has_result=$(echo "$tool_response" | jq -e '.result' > /dev/null 2>&1 && echo "yes" || echo "no")

if [ "$has_action" = "no" ] && [ "$has_result" = "no" ]; then
  echo "🚩 MAKER RED FLAG: Missing required fields 'action' and 'result' - vote discarded. Spawn another step-executor with IDENTICAL input." >&2
  exit 2
fi

# === EXTRACT STEP ID ===

# Try to get step_id from response JSON
step_id=$(echo "$tool_response" | jq -r '.step_id // empty')

if [ -z "$step_id" ]; then
  # Fallback: extract from tool_input prompt
  step_id=$(echo "$json" | jq -r '.tool_input.prompt // empty' | grep -oE 'step_[0-9]+' | head -1 || true)
fi

if [ -z "$step_id" ]; then
  # Last resort: hash the prompt
  step_id=$(echo "$json" | jq -r '.tool_input.prompt // empty' | md5sum | cut -c1-8)
fi

# === VOTING COLLECTION ===

VOTE_DIR="/tmp/maker-votes/${session_id}/${step_id}"
mkdir -p "$VOTE_DIR"

# Store this vote (normalized JSON)
echo "$tool_response" | jq -c '.' >> "$VOTE_DIR/votes.jsonl"

# Get script directory for check_winner.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for winner
if [ -f "$SCRIPT_DIR/check_winner.py" ]; then
  winner_result=$("$SCRIPT_DIR/check_winner.py" "$VOTE_DIR" 2>/dev/null || echo '{"decided":false}')
else
  # Fallback: simple count if Python script not found
  vote_count=$(wc -l < "$VOTE_DIR/votes.jsonl" | tr -d ' ')
  winner_result="{\"decided\":false,\"votes\":$vote_count}"
fi

# Parse result and return feedback via stderr (exit 2 ensures Claude sees it)
if echo "$winner_result" | jq -e '.decided == true' > /dev/null 2>&1; then
  votes=$(echo "$winner_result" | jq -r '.votes')
  margin=$(echo "$winner_result" | jq -r '.margin')
  winner=$(echo "$winner_result" | jq -c '.winner')

  # Update state tracking (if maker_state.py exists)
  if [ -f "$SCRIPT_DIR/maker_state.py" ] && [ -n "$session_id" ] && [ -n "$step_id" ]; then
    "$SCRIPT_DIR/maker_state.py" "$session_id" update "$step_id" "decided" "$winner" "$votes" "$margin" 0 2>/dev/null || true
  fi

  echo "✅ MAKER VOTE DECIDED: Winner confirmed! Margin: ${margin}, Total votes: ${votes}. Apply this action and proceed to next step. Winner: ${winner}" >&2
  exit 2
else
  vote_count=$(echo "$winner_result" | jq -r '.votes // 0')
  candidates=$(echo "$winner_result" | jq -r '.candidates // 1')

  # Track voting state (if maker_state.py exists)
  if [ -f "$SCRIPT_DIR/maker_state.py" ] && [ -n "$session_id" ] && [ -n "$step_id" ]; then
    "$SCRIPT_DIR/maker_state.py" "$session_id" update "$step_id" "voting" "null" "$vote_count" 0 0 2>/dev/null || true
  fi

  echo "⏳ MAKER VOTE PENDING: ${vote_count} votes collected, ${candidates} unique candidate(s). Need K-ahead (margin ≥ 3). Spawn another step-executor with IDENTICAL input." >&2
  exit 2
fi