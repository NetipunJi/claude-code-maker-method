#!/usr/bin/env bash
# MAKER Framework Setup Verification Script
# Checks that all required components are installed and working

echo "🔍 MAKER Framework Setup Verification"
echo "======================================"
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Hook directory exists
echo "✓ Checking hook directory..."
if [ ! -d ~/.claude/hooks ]; then
  echo "  ❌ ERROR: ~/.claude/hooks/ directory not found"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✅ Hook directory exists"
fi

# Check 2: Required Python scripts
echo ""
echo "✓ Checking required Python scripts..."
for script in maker_state.py maker_math.py check_winner.py; do
  if [ ! -f ~/.claude/hooks/$script ]; then
    echo "  ❌ ERROR: $script not found"
    ERRORS=$((ERRORS + 1))
  elif [ ! -x ~/.claude/hooks/$script ]; then
    echo "  ⚠️  WARNING: $script not executable (run: chmod +x ~/.claude/hooks/$script)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ✅ $script found and executable"
  fi
done

# Check 3: Hook shell script
echo ""
echo "✓ Checking hook shell script..."
if [ ! -f ~/.claude/hooks/maker-post-task.sh ]; then
  echo "  ❌ ERROR: maker-post-task.sh not found"
  ERRORS=$((ERRORS + 1))
elif [ ! -x ~/.claude/hooks/maker-post-task.sh ]; then
  echo "  ⚠️  WARNING: maker-post-task.sh not executable (run: chmod +x ~/.claude/hooks/maker-post-task.sh)"
  WARNINGS=$((WARNINGS + 1))
else
  echo "  ✅ maker-post-task.sh found and executable"
fi

# Check 4: Required dependencies
echo ""
echo "✓ Checking dependencies..."
if ! command -v jq &> /dev/null; then
  echo "  ❌ ERROR: jq not found (required for JSON parsing)"
  echo "     Install: brew install jq (macOS) or apt-get install jq (Linux)"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✅ jq found"
fi

if ! command -v python3 &> /dev/null; then
  echo "  ❌ ERROR: python3 not found"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✅ python3 found"
fi

# Check 5: Test Python scripts
echo ""
echo "✓ Testing Python scripts..."

if [ -f ~/.claude/hooks/maker_state.py ]; then
  if ~/.claude/hooks/maker_state.py test_session init 5 "test task" 3 >/dev/null 2>&1; then
    echo "  ✅ maker_state.py working"
    # Cleanup test
    rm -rf /tmp/maker-state/test_session 2>/dev/null
  else
    echo "  ❌ ERROR: maker_state.py failed to initialize test state"
    ERRORS=$((ERRORS + 1))
  fi
fi

if [ -f ~/.claude/hooks/maker_math.py ]; then
  if ~/.claude/hooks/maker_math.py recommend_k 0.7 5 >/dev/null 2>&1; then
    echo "  ✅ maker_math.py working"
  else
    echo "  ❌ ERROR: maker_math.py failed test calculation"
    ERRORS=$((ERRORS + 1))
  fi
fi

# Check 6: State and vote directories
echo ""
echo "✓ Checking temporary directories..."
mkdir -p /tmp/maker-state /tmp/maker-votes
if [ -d /tmp/maker-state ] && [ -w /tmp/maker-state ]; then
  echo "  ✅ /tmp/maker-state writable"
else
  echo "  ❌ ERROR: Cannot write to /tmp/maker-state"
  ERRORS=$((ERRORS + 1))
fi

if [ -d /tmp/maker-votes ] && [ -w /tmp/maker-votes ]; then
  echo "  ✅ /tmp/maker-votes writable"
else
  echo "  ❌ ERROR: Cannot write to /tmp/maker-votes"
  ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
echo "======================================"
echo "Summary:"
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo "✅ All checks passed! MAKER framework is ready to use."
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo "⚠️  Setup OK with warnings. MAKER should work but consider fixing warnings."
  exit 0
else
  echo "❌ Setup incomplete. Please fix errors above before using MAKER."
  exit 1
fi
