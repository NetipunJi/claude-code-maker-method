High-reliability task execution using MAKER framework (Massively Decomposed Agentic Process).

**Task:** $ARGUMENTS

---

## Phase 1: Decompose

Break the task into atomic subtasks. Output:
```
Step 1: [description] → Expected: [outcome]
Step 2: [description] → Expected: [outcome]
...
```

---

## Phase 2: Execute with Voting

For **each step**:

1. Spawn a `step-executor` subagent:
   ```
   Use step-executor subagent: "Execute step_1: [description]. Output JSON: {\"step_id\": \"step_1\", \"action\": \"...\", \"result\": \"...\"}"
   ```

2. **Check the hook feedback** in the response:
   - `MAKER VOTE DECIDED: Winner confirmed` → Apply action, proceed to next step
   - `MAKER VOTE PENDING: N votes collected` → Spawn another step-executor with **identical** input
   - `RED FLAG: ... discarded` → That vote was invalid, spawn another

3. Repeat until you see `VOTE DECIDED` (max 9 attempts per step)

4. **Important:** Use the exact same prompt for all voting attempts on the same step

---

## Phase 3: Report

After all steps complete:

```
MAKER Execution Report
======================
Total steps: N
Successful votes: N/N

Step 1: ✓ (votes: 3, margin: 3)
Step 2: ✓ (votes: 5, margin: 3, red-flagged: 1)
Step 3: ✗ (failed after 9 attempts)
...

Red-flagged outputs: N
Final result: [success/failed at step N]
```

---

## Rules

- Wait for `VOTE DECIDED` before applying any action
- The hook automatically tracks votes - you just spawn subagents
- Each subagent call for the same step must use **identical prompts**
- Stop if any step shows `VOTE PENDING` after 9 subagent calls
- Never skip voting - every step needs minimum 3 matching votes

---

Begin with Phase 1 decomposition now.
