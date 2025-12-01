**MAKER Framework: High-Reliability Task Execution**

Automated orchestrator for complex tasks using Massively Decomposed Agentic Process with conditional voting.

**Task:** $ARGUMENTS

---

I'll execute this task using the MAKER framework for near-perfect reliability. Here's how it works:

## 🔄 Automated Workflow

### Phase 1: Task Decomposition
Using the `orchestrator` agent to break down the task into atomic steps...

### Phase 2: Conditional Execution
- **Regular steps**: Execute once with single step-executor
- **[CRITICAL] steps**: Use parallel voting with k-ahead margin consensus (k determined by setup or default k=3)

### Phase 3: Automatic Vote Tracking
The hook system will provide real-time feedback:
- ✅ VOTE DECIDED → Winner confirmed, applying action
- ⏳ VOTE PENDING → More votes needed
- 🚩 RED FLAG → Invalid response, retrying

### Phase 4: Final Report
Complete metrics and success probability at the end.

---

## 📋 Execution Instructions

**You must follow this automated workflow:**

### Step 1: Initialize State and Determine k Value

**First, initialize the MAKER state** (required for dynamic k):

Use Bash to initialize state with session_id from current context:
```bash
hooks/maker_state.py "$session_id" init <estimated_total_steps> "$ARGUMENTS" <k_value>
```

Where:
- `estimated_total_steps`: Your best guess (e.g., 5, 10, 20...)
- `k_value`: The margin threshold to use (see options below)

**Option A: Use Setup Estimator (Recommended for complex tasks)**

Spawn the `setup-estimator` agent to calculate optimal k:
```
Use Task tool with subagent_type='setup-estimator':
"Analyze the task '$ARGUMENTS' and recommend optimal k value based on:
- Estimated total steps
- Task complexity (simple/medium/complex)
- Expected per-step success rate
Output JSON with recommended_k, reasoning, and cost estimates."
```

Extract the `recommended_k` from the response and use it when initializing state.

**Option B: Use Default k=3 (Fast path)**

Skip setup-estimator and use k=3 (provides 99%+ reliability for p>0.7).

Initialize state with k=3.

### Step 2: Decompose with Orchestrator

Spawn the `orchestrator` agent to break down the task:

```
Use Task tool with subagent_type='orchestrator':
"Decompose this task into atomic steps: $ARGUMENTS

Output format:
Step 1: [description] → Expected: [outcome]
Step 2: [CRITICAL] [description] → Expected: [outcome]
...

Mark steps as [CRITICAL] only if they require voting consensus (destructive ops, security-sensitive, complex refactoring)."
```

### Step 3: Execute Steps with Conditional Voting

For each step returned by the orchestrator:

**A. Regular Steps (no [CRITICAL] marker):**
1. Spawn 1 step-executor agent:
   ```
   Use Task tool with subagent_type='step-executor':
   "Execute step_N: [exact description from orchestrator]. Output JSON: {\"step_id\": \"step_N\", \"action\": \"what you did\", \"result\": \"outcome\"}"
   ```
2. Review the JSON response
3. Apply the action to the codebase/environment
4. Proceed to next step

**B. Critical Steps (marked [CRITICAL]):**
1. Spawn **k** step-executor agents **in parallel** (single message with k Task calls):
   ```
   In ONE message, use Task tool k times with IDENTICAL prompts:
   "Execute step_N: [CRITICAL] [exact description]. Output JSON: {\"step_id\": \"step_N\", \"action\": \"...\", \"result\": \"...\"}"

   Where k = the value you initialized in state (from setup-estimator or default k=3)
   ```

2. **Wait for hook feedback** after spawning:
   - If you see `✅ MAKER VOTE DECIDED` → Extract winner from feedback, apply action, proceed
   - If you see `⏳ MAKER VOTE PENDING (need margin ≥ k)` → Spawn k more step-executors with IDENTICAL prompt
   - If you see `🚩 MAKER RED FLAG` → That response was invalid, spawn another with IDENTICAL prompt

3. Repeat until `VOTE DECIDED` (max 3k total attempts, allowing 3 rounds of k votes)

4. **CRITICAL RULE:** Every voting attempt for the same step MUST use byte-for-byte identical prompts

5. **Dynamic k**: The hook system now retrieves k from state automatically. The k value in feedback messages will match what you initialized.

### Step 4: Track Progress

Use TodoWrite to track step execution:
- Create todo for each step from orchestrator
- Mark in_progress when executing
- Mark completed when action applied
- This helps with resumability if interrupted

### Step 5: Generate Final Report

After all steps complete, generate report:

```
MAKER Execution Report
======================
Session: [session_id]
Task: $ARGUMENTS
Status: [success/failed]

Total steps: N
Regular steps: N (executed once)
Critical steps: N (with voting)
Completed: N
Failed: N
Total votes cast: N
Red-flagged votes: N

Step Details:
✓ step_1: regular (no voting)
✓ step_2: [CRITICAL] votes=5, margin=3, red_flags=1
✓ step_3: regular (no voting)
...

Task success probability: 99.XX%
```

---

## 🎯 Start Execution Now

Begin by spawning the orchestrator agent to decompose the task...
