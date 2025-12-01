# MAKER Method Plugin Design

**Date:** 2025-12-01
**Status:** Design Complete
**Goal:** Convert MAKER framework into a distributable Claude Code plugin

## Overview

Transform the MAKER (Massively Decomposed Agentic Process) framework into a well-packaged Claude Code plugin that works locally and can be shared with the community. The plugin provides both a convenient `/maker` command for full workflows and granular skills for advanced composition.

## Design Decisions

### 1. Plugin Identity
- **Namespace:** `maker-method` (ties to research paper)
- **Interface:** Hybrid approach
  - Slash command: `/maker` for quick full workflows
  - Skills: High modularity for composition and advanced use cases
- **Distribution:** Personal use + community sharing

### 2. Modularity Strategy
High modularity with 5 granular skills:
- `maker-method:orchestrate` - Task decomposition only
- `maker-method:execute-step` - Single step execution
- `maker-method:vote` - Voting logic only
- `maker-method:estimate-k` - Setup and k-value estimation
- `maker-method:report` - Metrics and reporting

**Rationale:** Maximum composability - users can mix MAKER orchestrator with custom execution, or use MAKER voting in non-MAKER workflows.

### 3. Hook Management
- **Strategy:** Plugin-local hooks (no global pollution)
- **Location:** `~/.claude/plugins/maker-method/hooks/`
- **Registration:** Auto-configured in `.claude/settings.json` on install
- **Benefits:** Self-contained, easy uninstall, no conflicts

### 4. Dependency Handling
- **Python scripts:** Keep as-is for maintainability
- **Shims:** Shell wrappers check for Python 3 availability
- **Error handling:** Clear installation instructions if Python missing
- **Portability:** All paths reference `$PLUGIN_DIR` for flexibility

### 5. State Persistence
- **Location:** `~/.claude/plugins/maker-method/state/$session_id/`
- **Persistence:** Survives reboots for resume functionality
- **Isolation:** Per-session state directories
- **Cleanup:** Command to remove old sessions

### 6. Agent Structure
- **Dual approach:**
  - Source files in `agents/*.md` for documentation and maintenance
  - Prompts embedded in skills for reliable runtime execution
- **Benefits:** Easy to edit source, no file read dependencies at runtime

### 7. Documentation Depth
Comprehensive documentation including:
- Quick start and practical guide
- Mathematical framework explanation
- When to use each skill and advanced patterns
- Extensive examples and troubleshooting

### 8. Update Strategy
- **Self-updating:** `/maker-update` command
- **Safety:** Automatic backups before updates
- **State preservation:** Never delete user state during updates
- **Verification:** Test installation after update

---

## Plugin Structure

```
~/.claude/plugins/maker-method/
├── plugin.json                 # Plugin metadata & manifest
├── README.md                   # Comprehensive documentation
├── CHANGELOG.md                # Version history
├── install.sh                  # Installation script
├── uninstall.sh               # Uninstall script
├── commands/
│   ├── maker.md               # Main /maker workflow command
│   └── maker-update.md        # /maker-update self-updater
├── skills/
│   ├── orchestrate.md         # maker-method:orchestrate skill
│   ├── execute-step.md        # maker-method:execute-step skill
│   ├── vote.md                # maker-method:vote skill
│   ├── estimate-k.md          # maker-method:estimate-k skill
│   └── report.md              # maker-method:report skill
├── agents/
│   ├── orchestrator.md        # Source for orchestrator agent
│   ├── step-executor.md       # Source for step-executor agent
│   └── setup-estimator.md     # Source for setup-estimator agent
├── hooks/
│   ├── maker-post-task.sh     # PostToolUse hook
│   ├── check_winner.py        # Voting algorithm
│   ├── maker_math.py          # Mathematical framework
│   ├── maker_state.py         # State persistence
│   ├── update.sh              # Update helper script
│   ├── python-check.sh        # Python availability checker
│   ├── maker_state.sh         # Shim for maker_state.py
│   ├── maker_math.sh          # Shim for maker_math.py
│   └── check_winner.sh        # Shim for check_winner.py
├── state/                     # Runtime state (created on first use)
│   └── $session_id/           # Per-session execution state
├── tests/
│   ├── test_maker_math.py     # Unit tests for math module
│   ├── test_maker_state.py    # Unit tests for state module
│   ├── test_check_winner.py   # Unit tests for voting
│   ├── integration/
│   │   ├── test_workflow.sh   # End-to-end tests
│   │   └── test_skills.sh     # Skills composition tests
│   ├── smoke/                 # Real task tests
│   └── run_all.sh             # Test runner
└── docs/
    ├── MATHEMATICAL_FRAMEWORK.md
    └── PAPER_ALIGNMENT.md
```

---

## Plugin Manifest (plugin.json)

```json
{
  "name": "maker-method",
  "version": "1.0.0",
  "description": "MAKER Framework: Zero-error execution for complex multi-step tasks using decomposition and voting",
  "author": "Your Name",
  "license": "MIT",
  "repository": "https://github.com/yourusername/claude-code-maker-method",
  "claudeCodeVersion": ">=1.0.0",

  "commands": [
    {
      "name": "maker",
      "file": "commands/maker.md",
      "description": "Execute task using MAKER framework with conditional voting"
    },
    {
      "name": "maker-update",
      "file": "commands/maker-update.md",
      "description": "Update MAKER Method plugin to latest version"
    }
  ],

  "skills": [
    {
      "name": "orchestrate",
      "file": "skills/orchestrate.md",
      "description": "Decompose task into atomic steps with [CRITICAL] markers"
    },
    {
      "name": "execute-step",
      "file": "skills/execute-step.md",
      "description": "Execute single atomic step with temp=0.1 decorrelation"
    },
    {
      "name": "vote",
      "file": "skills/vote.md",
      "description": "Run k-ahead margin voting on critical decisions"
    },
    {
      "name": "estimate-k",
      "file": "skills/estimate-k.md",
      "description": "Calculate optimal k value based on task complexity"
    },
    {
      "name": "report",
      "file": "skills/report.md",
      "description": "Generate execution metrics and reliability report"
    }
  ],

  "hooks": {
    "PostToolUse": "hooks/maker-post-task.sh"
  }
}
```

---

## Skills Design

### maker-method:orchestrate
**Purpose:** Decompose tasks into atomic steps with [CRITICAL] markers

**Input:** Task description

**Output:** Numbered atomic steps, with [CRITICAL] markers for steps requiring voting

**Implementation:** Embeds orchestrator agent prompt directly

**Standalone Usage:**
```
Use Skill tool: "maker-method:orchestrate"
Prompt: "Decompose this task into atomic steps: Implement user authentication"
```

**Composition Example:** Use orchestrator for planning, then custom execution logic

---

### maker-method:execute-step
**Purpose:** Execute single atomic step with temp=0.1 decorrelation

**Input:**
- Step description
- step_id
- Expected outcome

**Output:** JSON with `{step_id, action, result}`

**Implementation:** Embeds step-executor agent prompt (temp=0.1)

**Standalone Usage:**
```
Use Skill tool: "maker-method:execute-step"
Prompt: "Execute step_1: Create User model with email and password fields"
```

**Composition Example:** Use in any workflow needing decorrelated execution

---

### maker-method:vote
**Purpose:** Run k-ahead margin voting on critical decisions

**Process:**
1. Spawns k instances of execute-step in parallel
2. Monitors hook feedback for VOTE DECIDED/PENDING/RED FLAG
3. Spawns additional executors if margin not reached
4. Extracts winner when decided
5. Cleans up votes

**Input:**
- Step description
- k value
- step_id

**Output:** Winning action with consensus metrics

**Standalone Usage:**
```
Use Skill tool: "maker-method:vote"
Prompt: "Vote on critical step_2: Delete production database migrations (k=5)"
```

**Composition Example:** Use MAKER voting for critical decisions in non-MAKER workflows

---

### maker-method:estimate-k
**Purpose:** Calculate optimal k value based on task complexity

**Process:**
1. Analyzes task description
2. Estimates complexity (simple/medium/complex)
3. Samples representative steps
4. Measures empirical success rate
5. Uses maker_math.py to calculate optimal k

**Output:**
- Recommended k value
- Reasoning
- Cost estimates
- Reliability prediction

**Standalone Usage:**
```
Use Skill tool: "maker-method:estimate-k"
Prompt: "Analyze task: Refactor authentication system. Recommend optimal k."
```

---

### maker-method:report
**Purpose:** Generate execution metrics and reliability report

**Process:**
1. Calls maker_state.py to load session state
2. Formats metrics (steps, votes, red flags)
3. Calculates success probability
4. Shows timeline

**Output:** Formatted report with all execution metrics

**Standalone Usage:**
```
Use Skill tool: "maker-method:report"
Prompt: "Generate report for current MAKER session"
```

---

## Hook Integration

### Plugin-Local Path Resolution

Hooks reference the plugin directory:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/maker-method/hooks/maker-post-task.sh"
          }
        ]
      }
    ]
  }
}
```

### Python Dependency Shims

Each Python script gets a shell wrapper:

**hooks/maker_state.sh:**
```bash
#!/bin/bash
PLUGIN_DIR="$HOME/.claude/plugins/maker-method"
source "$PLUGIN_DIR/hooks/python-check.sh"

check_python || exit 1
python3 "$PLUGIN_DIR/hooks/maker_state.py" "$@"
```

**hooks/python-check.sh:**
```bash
check_python() {
  if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 required for MAKER Method plugin"
    echo "Install: brew install python3 (macOS) or apt install python3 (Linux)"
    return 1
  fi
  return 0
}
```

### State Directory

- **Location:** `~/.claude/plugins/maker-method/state/$session_id/`
- **Structure:**
  ```
  state/
  └── $session_id/
      ├── execution.json          # Session metadata and progress
      └── votes/
          ├── step_1/
          │   └── votes.jsonl     # Vote records
          └── step_2/
              └── votes.jsonl
  ```
- **Persistence:** Survives reboots
- **Cleanup:** `/maker-cleanup` removes old sessions

---

## Main `/maker` Command Workflow

### Command Flow

```
/maker <task description>
  ↓
1. Check Python dependencies (via python-check.sh)
  ↓
2. Invoke maker-method:estimate-k skill
   - Analyzes task complexity
   - Recommends k value with reasoning
   - Shows cost/reliability estimates
  ↓
3. Initialize state with session_id
   - maker_state.sh "$session_id" init <steps> "<task>" <k>
   - Creates state directory
  ↓
4. Invoke maker-method:orchestrate skill
   - Decomposes into atomic steps
   - Marks [CRITICAL] steps for voting
  ↓
5. Execute steps sequentially:
   - Regular steps: maker-method:execute-step (once)
   - Critical steps: maker-method:vote (k parallel executors)
   - Track with TodoWrite
  ↓
6. Mark execution complete
   - maker_state.sh "$session_id" complete true
  ↓
7. Invoke maker-method:report skill
   - Generate final metrics
   - Display success probability
```

### User Experience Example

**User types:** `/maker Implement user authentication system`

**Assistant responds:**
1. "Checking dependencies..." ✓
2. "Analyzing task complexity..."
   - Recommended k=3 for 99.5% reliability
   - Expected 12 steps (4 critical)
   - Estimated cost: ~48 LLM calls
3. "Breaking down into atomic steps..."
   - Shows numbered steps with [CRITICAL] markers
4. Executes with real-time feedback:
   - ✓ Step 1: Create User model
   - ✓ Step 2: [CRITICAL] Add password hashing
     - ✅ VOTE DECIDED: Winner confirmed (margin: 3)
   - Progress via TodoWrite
5. Final report with metrics

### Error Handling

- **Python missing:** Clear installation instructions with OS-specific commands
- **Hooks not registered:** Auto-configure `.claude/settings.json` on first run
- **State corruption:** Offer to reinitialize with backup option
- **Vote never converges:** Suggest increasing k or simplifying step

---

## Self-Updating with `/maker-update`

### Update Workflow

```bash
/maker-update
  ↓
1. Check current version (from plugin.json)
  ↓
2. Fetch latest version info from GitHub API
   - Compare versions (semver)
  ↓
3. Show changelog if new version available
   - Display what's new
   - Ask for user confirmation
  ↓
4. Backup current installation
   - Copy to ~/.claude/plugins/maker-method.backup/
  ↓
5. Download and extract new version
   - Preserve state/ directory
   - Update all other files
  ↓
6. Verify installation
   - Test Python dependencies
   - Validate file integrity
  ↓
7. Update hooks registration if schema changed
  ↓
8. Report success with new version number
```

### Implementation

**commands/maker-update.md:**
```markdown
Check for updates to the MAKER Method plugin and install if available.

Repository: https://github.com/yourusername/claude-code-maker-method

Steps:
1. Use Bash to run: ~/.claude/plugins/maker-method/hooks/update.sh
2. Review changelog shown by update script
3. Confirm installation if user approves
4. Report new version or "Already up to date"
```

**hooks/update.sh:**
- Fetches latest release via GitHub API
- Compares versions (semver)
- Downloads release tarball
- Backs up current version
- Replaces files (except state/)
- Updates settings.json if needed
- Runs verification tests

### Safety Features

- Always backup before updating
- Preserve user state and active sessions
- Rollback capability if update fails
- Version pinning option for stability

---

## Documentation Structure

### README.md - Main Entry Point

**1. Quick Start** (200 words)
- Installation one-liner
- Simple `/maker` example
- Link to troubleshooting

**2. Core Concepts** (400 words)
- What is MAKER? (Decomposition + Voting)
- When to use it (complex multi-step tasks)
- How it achieves zero errors
- Link to research paper

**3. Skills Reference** (600 words)
Each skill documented with:
- Purpose and use case
- Input/output format
- Standalone usage example
- Composition patterns

**4. Command Reference** (300 words)
- `/maker` - Full workflow
- `/maker-update` - Self-update
- Usage patterns

**5. Advanced Topics** (500 words)
- Mathematical framework (formulas from paper)
- Choosing optimal k value
- Cost vs. reliability tradeoffs
- Custom voting strategies
- Resume interrupted tasks

**6. Troubleshooting** (400 words)
- Common errors with solutions
- Hook debugging
- State management issues
- Performance tuning

**7. Examples** (600 words)
- Simple task (k=1, no critical steps)
- Medium complexity (k=3, some voting)
- High-stakes task (k=5+, mostly critical)
- Composing skills manually

### Additional Documentation Files

**docs/MATHEMATICAL_FRAMEWORK.md**
Deep dive into:
- Per-step success probability formula
- Full task probability calculation
- Minimum k calculation
- Expected cost estimation
- Worked examples with real numbers

**docs/PAPER_ALIGNMENT.md**
For researchers:
- How implementation maps to paper sections
- Deviations and enhancements
- Benchmark comparisons
- Future improvements

**CHANGELOG.md**
Version history with:
- Breaking changes highlighted
- New features
- Bug fixes
- Migration guides for major versions

---

## Installation & Setup

### Installation Methods

**Method 1: Quick Install (Recommended)**
```bash
git clone https://github.com/yourusername/claude-code-maker-method.git
cd claude-code-maker-method
./install.sh
```

**Method 2: Manual Install**
```bash
mkdir -p ~/.claude/plugins
cp -r . ~/.claude/plugins/maker-method
chmod +x ~/.claude/plugins/maker-method/hooks/*.sh
chmod +x ~/.claude/plugins/maker-method/hooks/*.py
```

### Installation Script (install.sh) Tasks

1. **Verify Prerequisites**
   - Check Python 3 available
   - Check Claude Code installed
   - Verify git available (for updates)

2. **Copy Plugin Files**
   - Install to `~/.claude/plugins/maker-method/`
   - Set executable permissions on hooks

3. **Configure Hooks**
   - Backup existing `.claude/settings.json`
   - Merge hook configuration (preserve other hooks)
   - Validate JSON syntax

4. **Initialize State Directory**
   - Create `~/.claude/plugins/maker-method/state/`
   - Set appropriate permissions

5. **Verify Installation**
   - Test Python scripts run
   - Test hook registration
   - Print success message with next steps

### First-Run Experience

When user runs `/maker` for the first time:
1. Check if hooks properly registered
2. If not, show setup instructions
3. Create state directory if missing
4. Run quick self-test (simple 2-step task)
5. Show welcome message with links to docs

### Uninstall Process

**./uninstall.sh** or `/maker-uninstall` command:
1. Backup state directory (preserve session data)
2. Remove hook registration from settings.json
3. Remove plugin directory
4. Show uninstall confirmation with backup location

---

## Testing Strategy

### Unit Tests (Python Scripts)

**tests/test_maker_math.py:**
- Verify probability calculations match paper formulas
- Test k recommendation edge cases
- Validate cost estimation accuracy
- Test with p=0.5, 0.7, 0.9 across k=1,3,5,7

**tests/test_maker_state.py:**
- State initialization and updates
- Concurrent session handling
- State corruption recovery
- Resume functionality

**tests/test_check_winner.py:**
- Voting algorithm correctness
- Margin calculation (k-ahead)
- Red-flag detection (>700 tokens, malformed JSON)
- Tie-breaking behavior

### Integration Tests (Shell Scripts)

**tests/integration/test_workflow.sh:**
- End-to-end `/maker` execution
- Hook feedback appears correctly
- State persists across steps
- Final report generates

**tests/integration/test_skills.sh:**
- Each skill runs independently
- Skills compose correctly
- Agent prompts embed properly

### Smoke Tests (Real Tasks)

**tests/smoke/:**
- Simple task (3 steps, k=1, no critical)
- Medium task (10 steps, k=3, 2 critical)
- Complex task (20+ steps, k=5, many critical)
- Resume interrupted task
- Update plugin version

### Regression Tests

Track historical issues:
- Voting never converges (fixed by k tuning)
- State file corruption (fixed by atomic writes)
- Hook feedback missing (fixed by output buffering)

### Test Automation

**tests/run_all.sh:**
```bash
#!/bin/bash
echo "Running MAKER Method test suite..."
python3 -m pytest tests/
./tests/integration/test_workflow.sh
./tests/integration/test_skills.sh
echo "All tests passed!"
```

### CI/CD Integration

GitHub Actions workflow:
- Run tests on every commit
- Test on macOS and Linux
- Test with Python 3.8, 3.9, 3.10, 3.11
- Generate coverage report
- Block merge if tests fail

---

## Distribution & Publishing

### Repository Structure

```
claude-code-maker-method/
├── .github/
│   └── workflows/
│       ├── test.yml           # CI/CD tests
│       └── release.yml        # Automated releases
├── commands/                   # Plugin commands
├── skills/                     # Plugin skills
├── agents/                     # Agent source files
├── hooks/                      # Hook scripts
├── tests/                      # Test suite
├── docs/                       # Extended documentation
├── examples/                   # Usage examples
├── install.sh                  # Installation script
├── uninstall.sh               # Uninstall script
├── plugin.json                # Plugin manifest
├── README.md                  # Main documentation
├── CHANGELOG.md               # Version history
├── LICENSE                    # MIT license
└── .gitignore                 # Ignore state/ directory
```

### Release Process

1. **Version Bump**
   - Update version in `plugin.json`
   - Update `CHANGELOG.md` with changes
   - Tag commit: `git tag v1.1.0`

2. **Automated Release (GitHub Actions)**
   - Run full test suite
   - Create GitHub release
   - Generate release notes from CHANGELOG
   - Package as tarball/zip
   - Publish to GitHub Releases

3. **Plugin Registry Submission**
   - Submit to Claude Code plugin marketplace (if exists)
   - Include metadata: description, keywords, screenshots
   - Link to repository and documentation

### Distribution Channels

**Primary: GitHub**
- Main repository with releases
- Installation via git clone
- Updates via `/maker-update`

**Secondary: Plugin Marketplace**
- Official Claude Code registry (when available)
- One-click install from marketplace
- Automatic update notifications

**Tertiary: Package Managers** (Future)
- Homebrew tap for macOS
- apt repository for Linux
- npm package for easy installation

### Marketing & Discovery

- README badges (version, tests passing, license)
- GIF demos of `/maker` in action
- Blog post explaining MAKER framework
- Link from paper discussion forums
- Share in Claude Code community

---

## Implementation Phases

### Phase 1: Core Plugin Structure
1. Create plugin.json manifest
2. Set up directory structure
3. Create install.sh and uninstall.sh scripts
4. Test basic installation

### Phase 2: Skills Implementation
1. Create skill files with embedded agent prompts
2. Implement maker-method:orchestrate
3. Implement maker-method:execute-step
4. Implement maker-method:vote
5. Implement maker-method:estimate-k
6. Implement maker-method:report

### Phase 3: Hook Integration
1. Update hooks to use plugin-local paths
2. Create Python shims with dependency checking
3. Update state management for plugin directory
4. Test hook registration and feedback

### Phase 4: Commands
1. Implement /maker command (compose all skills)
2. Implement /maker-update command
3. Create update.sh helper script
4. Test end-to-end workflows

### Phase 5: Documentation
1. Write comprehensive README
2. Create MATHEMATICAL_FRAMEWORK.md
3. Create PAPER_ALIGNMENT.md
4. Write CHANGELOG
5. Add examples directory

### Phase 6: Testing
1. Write unit tests
2. Write integration tests
3. Create smoke tests
4. Set up CI/CD
5. Run full test suite

### Phase 7: Distribution
1. Set up GitHub repository
2. Configure GitHub Actions
3. Create first release
4. Submit to plugin marketplace
5. Announce to community

---

## Success Criteria

### Functional Requirements
- ✅ Plugin installs with one command
- ✅ `/maker` command executes full workflow
- ✅ All 5 skills work independently
- ✅ Skills compose correctly
- ✅ Hooks work from plugin-local paths
- ✅ State persists across sessions
- ✅ `/maker-update` updates successfully
- ✅ Python dependency checking works
- ✅ Error messages are clear and actionable

### Quality Requirements
- ✅ All tests pass (unit, integration, smoke)
- ✅ Works on macOS and Linux
- ✅ Works with Python 3.8+
- ✅ No global pollution (hooks, state)
- ✅ Clean uninstall (no residue)
- ✅ Comprehensive documentation
- ✅ Code follows Claude Code plugin best practices

### User Experience Requirements
- ✅ Installation takes < 1 minute
- ✅ First-run self-test succeeds
- ✅ Error messages guide users to solutions
- ✅ Updates preserve state
- ✅ Skills are discoverable
- ✅ Examples cover common use cases

---

## Future Enhancements

### v1.1
- Web UI for visualizing execution graphs
- Export reports as markdown/JSON
- Configurable red-flag thresholds
- Support for remote state storage

### v1.2
- Multi-language support (beyond Python)
- Integration with external CI/CD
- Parallel step execution (non-sequential)
- Advanced cost optimization strategies

### v2.0
- Plugin marketplace integration
- One-click install from marketplace
- Automatic dependency installation
- Cloud-hosted state option

---

## References

- **Paper:** [Solving a Million-Step LLM Task with Zero Errors](https://arxiv.org/abs/2511.09030)
- **Authors:** Elliot Meyerson, Giuseppe Paolo, Roberto Dailey, Hormoz Shahrzad, Olivier Francon, Conor F. Hayes, Xin Qiu, Babak Hodjat, Risto Miikkulainen
- **Claude Code Documentation:** https://claude.ai/code/docs
- **Plugin Development Guide:** (TBD)

---

## Appendix: Key Design Principles

1. **Composability:** Every component works standalone and in combination
2. **Self-containment:** No global pollution, easy install/uninstall
3. **Reliability:** Comprehensive testing at all levels
4. **Usability:** Clear errors, helpful documentation
5. **Maintainability:** Clean structure, dual agent approach
6. **Portability:** Works across platforms with minimal dependencies
7. **Transparency:** Open source, well-documented, aligned with paper

---

**Design Status:** ✅ Complete and validated
**Next Step:** Implementation
