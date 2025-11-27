Execute task using MAKER framework (Massively Decomposed Agentic Process).

Usage: /maker <task_description>
```
Steps:
1. Decompose: Use orchestrator agent to break into minimal subtasks
2. Execute: For each subtask, spawn 3+ parallel step-executor subagents
3. Vote: Collect outputs, apply first-to-ahead-by-3 voting
4. Red-flag: Discard overly long or malformed responses
5. Aggregate: Combine verified step outputs into final result

$ARGUMENTS
```

#### **Phase 5: Parallel Execution Pattern**

Each subagent operates in its own context, preventing pollution of the main conversation and keeping it focused on high-level objectives.

Run multiple autonomous coding agents simultaneously... Each agent tackles different components while maintaining full context awareness.

For parallel voting, use explicit subagent spawning:
```
Use 3 parallel subagents to execute step {step_id}:
- Each subagent runs step-executor with identical input
- Collect all outputs for voting
- Winner requires K=3 margin
```
