#!/usr/bin/env bash
set -euo pipefail

# MAKER Framework - PostToolUse Hook
# Collects votes from step-executor subagents and determines winners

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

# Flag 1: Response too long (>3000 chars ≈ 750 tokens)
response_length=${#tool_response}
if [ "$response_length" -gt 3000 ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"RED FLAG: Response too long (>750 tokens) - discarded per MAKER framework. Spawn another subagent with identical input."}}'
  exit 0
fi

# Flag 2: Check for valid JSON structure in response
if ! echo "$tool_response" | jq -e '.' > /dev/null 2>&1; then
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"RED FLAG: Malformed JSON response - discarded per MAKER framework. Spawn another subagent with identical input."}}'
  exit 0
fi

# Flag 3: Check for error in response
if echo "$tool_response" | jq -e '.error' > /dev/null 2>&1; then
  error_msg=$(echo "$tool_response" | jq -r '.error')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"RED FLAG: Subagent reported error: $error_msg - discarded. Spawn another subagent with identical input.\"}}"
  exit 0
fi

# === EXTRACT STEP ID ===

# Try to get step_id from response JSON
step_id=$(echo "$tool_response" | jq -r '.step_id // empty')

if [ -z "$step_id" ]; then
  # Fallback: extract from tool_input prompt
  step_id=$(echo "$json" | jq -r '.tool_input.prompt // empty' | grep -oE 'step_[0-9]+' | head -1 || echo "")
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

# Parse result and return appropriate feedback
if echo "$winner_result" | jq -e '.decided == true' > /dev/null 2>&1; then
  votes=$(echo "$winner_result" | jq -r '.votes')
  margin=$(echo "$winner_result" | jq -r '.margin')
  winner=$(echo "$winner_result" | jq -c '.winner')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"MAKER VOTE DECIDED: Winner confirmed with margin $margin (total votes: $votes). Apply this action and proceed to next step. Winner: $winner\"}}"
else
  vote_count=$(echo "$winner_result" | jq -r '.votes // 0')
  candidates=$(echo "$winner_result" | jq -r '.candidates // 1')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"MAKER VOTE PENDING: $vote_count votes collected, $candidates unique candidates, no K-ahead winner yet. Spawn another step-executor with IDENTICAL input.\"}}"
fi

exit 0
