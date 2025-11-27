#!/usr/bin/env python3
"""
MAKER Framework - Mathematical Utilities
Implements formulas from the paper for reliability and cost estimation
"""

import math
import json
import sys


def per_step_success_probability(p: float, k: int) -> float:
    """
    Calculate probability of selecting correct action with k-ahead voting.

    Formula: p(ai=a*) = 1 / (1 + ((1-p)/p)^k)

    Args:
        p: Base per-step success rate (0 < p < 1)
        k: Voting margin threshold

    Returns:
        Probability of correct selection after voting
    """
    if p <= 0 or p >= 1:
        raise ValueError("p must be in (0, 1)")
    if k < 1:
        raise ValueError("k must be >= 1")

    ratio = (1 - p) / p
    return 1 / (1 + ratio**k)


def full_task_success_probability(p: float, k: int, s: int, m: int = 1) -> float:
    """
    Calculate probability of completing full task with zero errors.

    Formula: p_full = (1 + ((1-p)/p)^k)^(-s/m)

    Args:
        p: Base per-step success rate
        k: Voting margin threshold
        s: Total number of steps
        m: Steps per subtask (1 for MAD)

    Returns:
        Probability of zero-error task completion
    """
    if p <= 0 or p >= 1:
        raise ValueError("p must be in (0, 1)")
    if k < 1 or s < 1 or m < 1:
        raise ValueError("k, s, m must be >= 1")

    ratio = (1 - p) / p
    exponent = -s / m
    return (1 + ratio**k) ** exponent


def minimum_k_for_target(p: float, s: int, target: float = 0.99, m: int = 1) -> int:
    """
    Calculate minimum k needed to achieve target task success probability.

    Formula: k_min = ⌈ln(t^(-m/s) - 1) / ln((1-p)/p)⌉

    Args:
        p: Base per-step success rate
        s: Total number of steps
        target: Target task success probability (default 0.99)
        m: Steps per subtask (1 for MAD)

    Returns:
        Minimum k value (ceiling)
    """
    if p <= 0 or p >= 1:
        raise ValueError("p must be in (0, 1)")
    if target <= 0 or target >= 1:
        raise ValueError("target must be in (0, 1)")
    if s < 1 or m < 1:
        raise ValueError("s, m must be >= 1")

    # Handle edge case: if target is too close to 1
    inner = target ** (-m/s) - 1
    if inner <= 0:
        return 1  # Already achievable

    ratio = (1 - p) / p
    if ratio <= 0:
        return 1

    k_min = math.log(inner) / math.log(ratio)
    return max(1, math.ceil(k_min))


def expected_cost_estimate(p: float, k: int, s: int, cost_per_call: float) -> dict:
    """
    Estimate expected total voting cost.

    Expected votes per step ≈ k + E[runner_up votes]
    For simplicity, we approximate as k * 1.5 (empirical heuristic)

    Args:
        p: Base per-step success rate
        k: Voting margin threshold
        s: Total steps
        cost_per_call: API cost per LLM call

    Returns:
        Dict with cost breakdown
    """
    # Simplified estimate: assume winner needs k votes, runner-up gets k-1 on average
    # Plus red-flagged attempts (assume 10% red-flag rate)
    votes_per_step = k + (k - 1) * 0.5 + (k * 0.1)  # Winner + partial runner-up + red-flags

    total_votes = votes_per_step * s
    total_cost = total_votes * cost_per_call

    return {
        "votes_per_step": round(votes_per_step, 2),
        "total_votes": round(total_votes, 1),
        "total_cost": round(total_cost, 4),
        "cost_per_step": round(votes_per_step * cost_per_call, 4)
    }


def recommend_k(p: float, s: int, task_type: str = "standard") -> dict:
    """
    Recommend optimal k based on task parameters.

    Args:
        p: Estimated per-step success rate
        s: Estimated total steps
        task_type: "fast", "standard", or "high_stakes"

    Returns:
        Recommendation dict with k, reliability, and reasoning
    """
    targets = {
        "fast": 0.90,
        "standard": 0.99,
        "high_stakes": 0.999
    }

    target = targets.get(task_type, 0.99)
    k_min = minimum_k_for_target(p, s, target)

    # Add safety margin
    recommended_k = k_min if task_type == "fast" else max(3, k_min)

    actual_reliability = full_task_success_probability(p, recommended_k, s)

    return {
        "recommended_k": recommended_k,
        "k_min": k_min,
        "task_success_probability": round(actual_reliability, 4),
        "target": target,
        "reasoning": f"For p={p:.2f} and s={s} steps, k={recommended_k} achieves {actual_reliability:.1%} reliability"
    }


def main():
    """CLI interface for MAKER math utilities."""
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: maker_math.py <command> [args]",
            "commands": {
                "recommend_k": "maker_math.py recommend_k <p> <s> [task_type]",
                "full_probability": "maker_math.py full_probability <p> <k> <s>",
                "cost_estimate": "maker_math.py cost_estimate <p> <k> <s> <cost_per_call>"
            }
        }))
        sys.exit(1)

    command = sys.argv[1]

    try:
        if command == "recommend_k":
            p = float(sys.argv[2])
            s = int(sys.argv[3])
            task_type = sys.argv[4] if len(sys.argv) > 4 else "standard"
            result = recommend_k(p, s, task_type)
            print(json.dumps(result))

        elif command == "full_probability":
            p = float(sys.argv[2])
            k = int(sys.argv[3])
            s = int(sys.argv[4])
            prob = full_task_success_probability(p, k, s)
            print(json.dumps({"probability": round(prob, 6)}))

        elif command == "cost_estimate":
            p = float(sys.argv[2])
            k = int(sys.argv[3])
            s = int(sys.argv[4])
            cost = float(sys.argv[5])
            result = expected_cost_estimate(p, k, s, cost)
            print(json.dumps(result))

        else:
            print(json.dumps({"error": f"Unknown command: {command}"}))
            sys.exit(1)

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
