#!/usr/bin/env bash
# MAKER Framework End-to-End Workflow Test
# Tests the complete workflow from initialization to report generation

set -e  # Exit on error

echo "🧪 MAKER Framework End-to-End Test"
echo "==================================="
echo ""

TEST_SESSION="test-$(date +%s)"
HOOKS_DIR="$HOME/.claude/hooks"

# Cleanup function
cleanup() {
  echo ""
  echo "🧹 Cleaning up test data..."
  rm -rf "/tmp/maker-state/$TEST_SESSION" 2>/dev/null || true
  rm -rf "/tmp/maker-votes/$TEST_SESSION" 2>/dev/null || true
  echo "✅ Cleanup complete"
}

trap cleanup EXIT

# Test 1: Initialize state
echo "Test 1: Initialize state with k=3"
echo "-----------------------------------"
if ! "$HOOKS_DIR/maker_state.py" "$TEST_SESSION" init 5 "Test task execution" 3 >/dev/null; then
  echo "❌ FAILED: Could not initialize state"
  exit 1
fi
echo "✅ PASSED: State initialized"

# Test 2: Verify k value stored
echo ""
echo "Test 2: Retrieve k value from state"
echo "-----------------------------------"
k_result=$("$HOOKS_DIR/maker_state.py" "$TEST_SESSION" get-k 2>/dev/null)
k_value=$(echo "$k_result" | jq -r '.k')
if [ "$k_value" != "3" ]; then
  echo "❌ FAILED: Expected k=3, got k=$k_value"
  exit 1
fi
echo "✅ PASSED: k value correctly stored and retrieved (k=$k_value)"

# Test 3: Update step (simulate regular step)
echo ""
echo "Test 3: Update step (regular, no voting)"
echo "-----------------------------------"
if ! "$HOOKS_DIR/maker_state.py" "$TEST_SESSION" update "step_1" "decided" "null" 0 0 0 >/dev/null; then
  echo "❌ FAILED: Could not update step"
  exit 1
fi
echo "✅ PASSED: Regular step updated"

# Test 4: Simulate critical step with voting
echo ""
echo "Test 4: Simulate critical step with voting"
echo "-----------------------------------"
# Create vote directory
VOTE_DIR="/tmp/maker-votes/$TEST_SESSION/step_2"
mkdir -p "$VOTE_DIR"

# Add some test votes (3 for action A, 0 for action B = margin of 3, meets k=3)
echo '{"step_id":"step_2","action":"action A","result":"result A"}' >> "$VOTE_DIR/votes.jsonl"
echo '{"step_id":"step_2","action":"action A","result":"result A"}' >> "$VOTE_DIR/votes.jsonl"
echo '{"step_id":"step_2","action":"action A","result":"result A"}' >> "$VOTE_DIR/votes.jsonl"

# Check for winner
winner_result=$("$HOOKS_DIR/check_winner.py" "$VOTE_DIR" "--k=3" 2>/dev/null)
decided=$(echo "$winner_result" | jq -r '.decided')
if [ "$decided" != "true" ]; then
  echo "❌ FAILED: Expected vote to be decided with k=3 margin"
  exit 1
fi
echo "✅ PASSED: Winner decided with k-ahead margin"

# Test 5: Update state with winner
echo ""
echo "Test 5: Update state with decided vote"
echo "-----------------------------------"
winner=$(echo "$winner_result" | jq -c '.winner')
votes=$(echo "$winner_result" | jq -r '.votes')
margin=$(echo "$winner_result" | jq -r '.margin')

if ! "$HOOKS_DIR/maker_state.py" "$TEST_SESSION" update "step_2" "decided" "$winner" "$votes" "$margin" 0 >/dev/null; then
  echo "❌ FAILED: Could not update state with winner"
  exit 1
fi
echo "✅ PASSED: State updated with winner (votes=$votes, margin=$margin)"

# Test 6: Clear votes
echo ""
echo "Test 6: Clear votes after applying winner"
echo "-----------------------------------"
"$HOOKS_DIR/check_winner.py" "$VOTE_DIR" --clear >/dev/null
if [ -f "$VOTE_DIR/votes.jsonl" ]; then
  echo "❌ FAILED: Votes file still exists after cleanup"
  exit 1
fi
echo "✅ PASSED: Votes cleared successfully"

# Test 7: Add more steps
echo ""
echo "Test 7: Add remaining steps"
echo "-----------------------------------"
"$HOOKS_DIR/maker_state.py" "$TEST_SESSION" update "step_3" "decided" "null" 0 0 0 >/dev/null
"$HOOKS_DIR/maker_state.py" "$TEST_SESSION" update "step_4" "decided" "null" 0 0 0 >/dev/null
"$HOOKS_DIR/maker_state.py" "$TEST_SESSION" update "step_5" "decided" "null" 0 0 0 >/dev/null
echo "✅ PASSED: All steps completed"

# Test 8: Mark complete
echo ""
echo "Test 8: Mark execution as complete"
echo "-----------------------------------"
if ! "$HOOKS_DIR/maker_state.py" "$TEST_SESSION" complete true >/dev/null; then
  echo "❌ FAILED: Could not mark execution complete"
  exit 1
fi
echo "✅ PASSED: Execution marked as complete"

# Test 9: Generate report
echo ""
echo "Test 9: Generate final report"
echo "-----------------------------------"
report=$("$HOOKS_DIR/maker_state.py" "$TEST_SESSION" report 2>/dev/null)
if [ -z "$report" ]; then
  echo "❌ FAILED: Report generation produced no output"
  exit 1
fi

# Verify report contains expected data
if ! echo "$report" | grep -q "Session: $TEST_SESSION"; then
  echo "❌ FAILED: Report missing session ID"
  exit 1
fi

if ! echo "$report" | grep -q "Status: success"; then
  echo "❌ FAILED: Report missing success status"
  exit 1
fi

if ! echo "$report" | grep -q "Total steps: 5"; then
  echo "❌ FAILED: Report has wrong step count"
  exit 1
fi

if ! echo "$report" | grep -q "Completed: 5"; then
  echo "❌ FAILED: Report has wrong completed count"
  exit 1
fi

echo "✅ PASSED: Report generated with correct data"
echo ""
echo "📊 Sample report output:"
echo "$report" | head -20

# Test 10: Resume point check
echo ""
echo "Test 10: Verify resume point (should show complete)"
echo "-----------------------------------"
resume=$("$HOOKS_DIR/maker_state.py" "$TEST_SESSION" resume 2>/dev/null)
can_resume=$(echo "$resume" | jq -r '.can_resume')
if [ "$can_resume" != "false" ]; then
  echo "❌ FAILED: Completed task should not be resumable"
  exit 1
fi
echo "✅ PASSED: Resume correctly shows task complete"

# All tests passed
echo ""
echo "==================================="
echo "✅ All 10 tests PASSED!"
echo "==================================="
echo ""
echo "MAKER framework workflow verified:"
echo "  ✓ State initialization with k value"
echo "  ✓ K value storage and retrieval"
echo "  ✓ Regular step updates"
echo "  ✓ Critical step voting with k-ahead"
echo "  ✓ Winner decision and state update"
echo "  ✓ Vote cleanup"
echo "  ✓ Multi-step execution"
echo "  ✓ Execution completion marking"
echo "  ✓ Report generation"
echo "  ✓ Resume point tracking"
echo ""
echo "🎉 MAKER framework is fully functional!"
