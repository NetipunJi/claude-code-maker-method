#!/usr/bin/env python3
"""
First-to-ahead-by-K voting for MAKER framework.
Returns winner when one candidate leads by K votes.
"""

import sys
import json
from collections import Counter
from pathlib import Path

K = 3  # Margin required to declare winner

def normalize_vote(vote_str: str) -> str:
    """Normalize JSON for comparison (handles whitespace differences)."""
    try:
        parsed = json.loads(vote_str.strip())
        return json.dumps(parsed, sort_keys=True, separators=(',', ':'))
    except json.JSONDecodeError:
        return None  # Will be filtered out

def check_winner(vote_dir: str) -> dict:
    votes_file = Path(vote_dir) / "votes.jsonl"

    if not votes_file.exists():
        return {"decided": False, "votes": 0, "reason": "No votes file"}

    # Read and normalize votes
    raw_votes = votes_file.read_text().strip().split('\n')
    normalized = [normalize_vote(v) for v in raw_votes if v.strip()]
    valid_votes = [v for v in normalized if v is not None]

    if len(valid_votes) == 0:
        return {"decided": False, "votes": 0, "reason": "No valid votes"}

    # Count votes
    counts = Counter(valid_votes)

    # Check for K-ahead winner
    sorted_counts = counts.most_common()
    leader_vote, leader_count = sorted_counts[0]

    if len(sorted_counts) == 1:
        # Only one candidate
        if leader_count >= K:
            return {
                "decided": True,
                "winner": json.loads(leader_vote),
                "votes": leader_count,
                "margin": leader_count
            }
    else:
        # Multiple candidates - check margin
        runner_up_count = sorted_counts[1][1]
        margin = leader_count - runner_up_count

        if margin >= K:
            return {
                "decided": True,
                "winner": json.loads(leader_vote),
                "votes": leader_count,
                "margin": margin
            }

    return {
        "decided": False,
        "votes": len(valid_votes),
        "leader_count": leader_count,
        "candidates": len(counts),
        "reason": f"No K-ahead winner yet (need margin >= {K})"
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: check_winner.py <vote_dir>"}))
        sys.exit(1)

    result = check_winner(sys.argv[1])
    print(json.dumps(result))