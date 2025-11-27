#!/usr/bin/env bash
set -euo pipefail

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

# === RED-FLAG DETECTION ===

# Flag 1: Response too long (>3000 chars ≈ 750 tokens)
response_length=${#tool_response}
if [ "$response_length" -gt 3000 ]; then
  echo '{"decision":"block","reason":"Response too long - likely confused. Discarding vote.","hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"RED FLAG: Overly long response discarded per MAKER framework"}}' 
  exit 0
fi

# Flag 2: Check for valid JSON structure in response
if ! echo "$tool_response" | jq -e '.' > /dev/null 2>&1; then
  echo '{"decision":"block","reason":"Malformed response structure. Discarding vote.","hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"RED FLAG: Non-JSON response discarded per MAKER framework"}}'
  exit 0
fi

# === VOTING COLLECTION ===

# Extract step_id from the task input or generate from hash
step_id=$(echo "$json" | jq -r '.tool_input.prompt // empty' | md5sum | cut -c1-8)

VOTE_DIR="/tmp/maker-votes/${session_id}/${step_id}"
mkdir -p "$VOTE_DIR"

# Store this vote
echo "$tool_response" >> "$VOTE_DIR/votes.jsonl"

# Check for winner
winner_result=$("$CLAUDE_PROJECT_DIR/.claude/hooks/check_winner.py" "$VOTE_DIR" 2>/dev/null || echo '{"decided":false}')

if echo "$winner_result" | jq -e '.decided == true' > /dev/null 2>&1; then
  winner=$(echo "$winner_result" | jq -r '.winner')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"MAKER VOTE DECIDED: Winner confirmed with K-ahead margin. Result: $winner\"}}"
else
  vote_count=$(wc -l < "$VOTE_DIR/votes.jsonl" | tr -d ' ')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"MAKER VOTE PENDING: $vote_count votes collected, no K-ahead winner yet.\"}}"
fi

exit 0