High-reliability task execution using MAKER framework (Massively Decomposed Agentic Process).

**Task:** $ARGUMENTS

---

## Phase 0: Setup (Optional but Recommended)

For complex tasks (>20 steps) or when optimizing cost/reliability:

1. Use `setup-estimator` subagent to calculate optimal k:
   ```
   Estimate task parameters: total steps, complexity, recommended k value
   ```

2. For quick tasks, use defaults: k=3, 700-token limit

---

## Phase 1: Decompose

Break the task into atomic subtasks using `orchestrator` or directly:

```
Step 1: [description] → Expected: [outcome]
Step 2: [description] → Expected: [outcome]
...
```

**Atomic means:** Each step is one file edit, one command, one function change.

---

## Phase 2: Execute with Parallel Voting

For **each step**:

1. **Parallel voting (PREFERRED):** Spawn K=3 `step-executor` subagents simultaneously:
   ```
   In a single message with 3 Task tool calls, all with identical prompts:
   "Execute step_1: [description]. Output JSON: {\"step_id\": \"step_1\", \"action\": \"...\", \"result\": \"...\"}"
   ```

2. **Check the hook feedback** after each batch:
   - `✅ MAKER VOTE DECIDED` → Apply the winner action, proceed to next step
   - `⏳ MAKER VOTE PENDING` → Spawn more step-executors with **identical** input
   - `🚩 MAKER RED FLAG` → That vote was invalid (too long, malformed, etc.), spawn another

3. Continue until `VOTE DECIDED` (max 9 total attempts per step)

4. **Critical:** All voting attempts for the same step must use **byte-for-byte identical prompts**

**Performance optimization:** Start with 3 parallel executors. If voting isn't decided, spawn 2 more. Repeat until winner emerges.

---

## Phase 3: State & Metrics

The system automatically tracks:
- Vote counts and margins per step
- Red-flagged responses
- Execution progress (resumable if interrupted)
- Cost estimates

Access metrics:
```bash
~/.claude/hooks/maker_state.py <session_id> report
```

---

## Phase 4: Report

After all steps complete:

```
MAKER Execution Report
======================
Total steps: N
Successful votes: N/N

Step 1: ✓ (votes: 3, margin: 3, red-flags: 0)
Step 2: ✓ (votes: 5, margin: 3, red-flags: 1)
Step 3: ✗ (failed after 9 attempts)
...

Total votes cast: N
Red-flagged outputs: N
Task success probability: 99.X%
Final result: [success/failed at step N]
```

---

## Rules

- **Parallel execution:** Spawn multiple step-executors per step for faster voting
- **Identical prompts:** Every vote for the same step must use exact same prompt
- **Wait for winner:** Only apply actions after `VOTE DECIDED`
- **Red flags mean retry:** Schema errors, long responses (>700 tokens), malformed JSON
- **Never skip voting:** Every step needs K-ahead consensus (default: margin ≥ 3)
- **Temperature decorrelation:** step-executor uses temp=0.1 to reduce correlated failures
- **State persistence:** Progress is automatically saved, can resume if interrupted

---

Begin with Phase 1 decomposition now.
