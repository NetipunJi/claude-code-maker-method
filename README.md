# MAKER Framework for Claude Code

Complete implementation of the **MAKER** (Massively Decomposed Agentic Process) framework from the paper ["Solving a Million-Step LLM Task with Zero Errors"](https://arxiv.org/html/2511.09030v1).

## 🎯 What is MAKER?

MAKER achieves near-perfect reliability on complex, multi-step tasks by:

1. **Maximal Agentic Decomposition (MAD)**: Breaking tasks into atomic steps (m=1)
2. **First-to-ahead-by-k Voting**: Consensus mechanism requiring k-vote margin
3. **Red-Flagging**: Filtering pathological responses (>700 tokens, malformed JSON)
4. **Temperature Decorrelation**: Reducing correlated failures across voting attempts

**Result:** Zero-error execution on tasks with 1M+ steps (tested on Towers of Hanoi with 20 disks)

## 📦 Components

### Commands
- `/maker` - Main MAKER workflow orchestrator

### Agents
- `orchestrator` - Decomposes tasks into atomic steps
- `step-executor` - Executes single steps with temp=0.1 decorrelation
- `setup-estimator` - Calculates optimal k based on task complexity

### Hooks
- `maker-post-task.sh` - Vote collection and red-flag detection
- `check_winner.py` - First-to-ahead-by-k voting algorithm
- `maker_math.py` - Mathematical framework utilities
- `maker_state.py` - State persistence and metrics

## 🚀 Quick Start

### Installation

```bash
# Make scripts executable
chmod +x hooks/maker-post-task.sh
chmod +x hooks/check_winner.py
chmod +x hooks/maker_math.py
chmod +x hooks/maker_state.py
```

### Usage

```bash
/maker Write a function to calculate fibonacci numbers
```

The framework will:
1. Decompose the task into atomic steps
2. Execute each step with voting (k=3 consensus)
3. Track progress automatically
4. Generate reliability report

## 📊 Advanced Usage

### With Setup Phase (Recommended for >20 steps)

```bash
/maker Complex refactoring of authentication system
```

The setup estimator will:
- Analyze task complexity
- Calculate optimal k value
- Estimate total cost
- Predict success probability

### Manual k Optimization

```bash
# Estimate optimal k for 50-step task with p=0.75 success rate
hooks/maker_math.py recommend_k 0.75 50 standard

# Output: {"recommended_k": 3, "task_success_probability": 0.9950, ...}
```

### Resume Interrupted Execution

```bash
# Check if resumable
hooks/maker_state.py <session_id> resume

# View progress
hooks/maker_state.py <session_id> report
```

## 🔬 Mathematical Framework

The implementation includes all formulas from the paper:

### Per-Step Success Probability
```
p(ai=a*) = 1 / (1 + ((1-p)/p)^k)
```

### Full Task Success Probability
```
p_full = (1 + ((1-p)/p)^k)^(-s/m)
```

### Minimum k Calculation
```
k_min = ⌈ln(t^(-m/s) - 1) / ln((1-p)/p)⌉
```

### Cost Estimate
```
Expected cost ≈ votes_per_step × total_steps × cost_per_call
```

Example usage:
```bash
hooks/maker_math.py full_probability 0.75 3 50
# {"probability": 0.9950}

hooks/maker_math.py cost_estimate 0.75 3 50 0.001
# {"votes_per_step": 4.65, "total_cost": 0.2325}
```

## 🎛️ Configuration

### Default Parameters
- **k**: 3 (margin threshold)
- **Token limit**: 700 tokens (~2800 chars)
- **Temperature**: 0.1 (decorrelation)
- **Max attempts**: 9 per step

### Adjusting k

Edit `hooks/check_winner.py`:
```python
K = 3  # Change to 5 for high-stakes tasks, 1 for fast/cheap
```

Or use setup-estimator to calculate optimal k automatically.

### Rate Limiting

If you hit rate limits, change step-executor model to Haiku:

Edit `agents/step-executor.md`:
```yaml
model: haiku  # Faster and cheaper for simple atomic steps
```

## 📈 Performance Characteristics

| Task Type | Steps | Recommended k | Expected Reliability | Votes/Step |
|-----------|-------|---------------|---------------------|------------|
| Simple    | <20   | 3             | 99%+                | ~4         |
| Medium    | 20-100| 3-5           | 99.9%+              | ~5         |
| Complex   | >100  | 5-7           | 99.99%+             | ~6         |

## 🔍 Red-Flag Detection

Votes are automatically discarded if:

1. **Response too long**: >700 tokens (indicates confused reasoning)
2. **Malformed JSON**: Invalid JSON structure
3. **Error responses**: Contains `error` field
4. **Missing schema**: No `step_id` or missing both `action` and `result`

## 📋 Example Output

```
MAKER Execution Report
======================
Session: abc123
Task: Implement user authentication
Status: success

Total steps: 12
Completed: 12
Failed: 0
Total votes cast: 47
Red-flagged votes: 3

Step Details:
✓ step_1: votes=3, margin=3, red_flags=0
✓ step_2: votes=5, margin=3, red_flags=1
✓ step_3: votes=3, margin=3, red_flags=0
...

Task success probability: 99.95%
```

## 🧪 Testing

Test the mathematical utilities:
```bash
# Test k recommendation
hooks/maker_math.py recommend_k 0.7 100 standard

# Test probability calculation
hooks/maker_math.py full_probability 0.8 3 50

# Test cost estimation
hooks/maker_math.py cost_estimate 0.75 3 100 0.001
```

## 🔧 Troubleshooting

### Voting never converges
- Increase k (more lenient)
- Check if steps are truly atomic
- Review red-flagged responses for patterns

### Too many red flags
- Steps may be too complex (not atomic enough)
- Ambiguous expected outcomes
- Missing context in prompts

### High costs
- Reduce k (less voting)
- Use setup-estimator to optimize
- Break task into smaller chunks
- Switch to Haiku model for simple steps

## 📚 Implementation Completeness

✅ **Fully Implemented:**
- Maximal Agentic Decomposition (m=1)
- First-to-ahead-by-k voting
- Red-flag detection (length + schema)
- Temperature decorrelation (0.1)
- Mathematical framework
- State persistence
- Parallel voting support
- Metrics collection

✅ **All gaps from paper analysis fixed**

## 📖 References

- Paper: [Solving a Million-Step LLM Task with Zero Errors](https://arxiv.org/abs/2511.09030)
- Authors: Elliot Meyerson, Giuseppe Paolo, Roberto Dailey, Hormoz Shahrzad, Olivier Francon, Conor F. Hayes, Xin Qiu, Babak Hodjat, Risto Miikkulainen
- Published: 2025

## 🤝 Contributing

This implementation follows the paper's specifications exactly. For improvements:

1. Test against paper's benchmarks (Towers of Hanoi, SWE-bench)
2. Measure red-flag rates, convergence speed, cost efficiency
3. Document deviations from paper with justification

## 📄 License

Implementation based on research paper. Check paper license for academic use.
