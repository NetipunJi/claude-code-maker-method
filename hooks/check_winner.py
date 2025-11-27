#!/usr/bin/env python3
"""
MAKER Framework - First-to-ahead-by-K Voting

Returns winner when one candidate leads by K votes.
Based on the MAKER paper: "Solving a Million-Step LLM Task with Zero Errors"
"""

import sys
import json
from collections import Counter
from pathlib import Path

K = 3  # Margin required to declare winner


def normalize_vote(vote_str: str) -> str | None:
    """Normalize JSON for comparison (handles whitespace differences)."""
    try:
        parsed = json.loads(vote_str.strip())
        # Remove step_id for comparison if present (we want to compare actions/results)
        if isinstance(parsed, dict):
            # Keep only action and result for comparison
            comparable = {
                "action": parsed.get("action", ""),
                "result": parsed.get("result", "")
            }
            return json.dumps(comparable, sort_keys=True, separators=(',', ':'))
        return json.dumps(parsed, sort_keys=True, separators=(',', ':'))
    except json.JSONDecodeError:
        return None  # Will be filtered out


def check_winner(vote_dir: str) -> dict:
    """
    Check if we have a K-ahead winner.
    
    Returns:
        dict with 'decided', 'winner', 'votes', 'margin', etc.
    """
    votes_file = Path(vote_dir) / "votes.jsonl"
    
    if not votes_file.exists():
        return {"decided": False, "votes": 0, "reason": "No votes file"}
    
    # Read and normalize votes
    raw_votes = votes_file.read_text().strip().split('\n')
    
    # Keep original votes for returning winner
    original_votes = []
    normalized_votes = []
    
    for v in raw_votes:
        if not v.strip():
            continue
        normalized = normalize_vote(v)
        if normalized is not None:
            original_votes.append(v)
            normalized_votes.append(normalized)
    
    if len(normalized_votes) == 0:
        return {"decided": False, "votes": 0, "reason": "No valid votes"}
    
    # Count votes by normalized form
    counts = Counter(normalized_votes)
    
    # Map normalized back to original for winner retrieval
    norm_to_original = {}
    for orig, norm in zip(original_votes, normalized_votes):
        if norm not in norm_to_original:
            norm_to_original[norm] = orig
    
    # Check for K-ahead winner
    sorted_counts = counts.most_common()
    leader_norm, leader_count = sorted_counts[0]
    
    if len(sorted_counts) == 1:
        # Only one candidate - need K votes to confirm
        if leader_count >= K:
            return {
                "decided": True,
                "winner": json.loads(norm_to_original[leader_norm]),
                "votes": leader_count,
                "margin": leader_count,
                "candidates": 1
            }
    else:
        # Multiple candidates - check margin
        runner_up_count = sorted_counts[1][1]
        margin = leader_count - runner_up_count
        
        if margin >= K:
            return {
                "decided": True,
                "winner": json.loads(norm_to_original[leader_norm]),
                "votes": leader_count,
                "margin": margin,
                "candidates": len(counts)
            }
    
    return {
        "decided": False,
        "votes": len(normalized_votes),
        "leader_count": leader_count,
        "candidates": len(counts),
        "reason": f"No K-ahead winner yet (need margin >= {K})"
    }


def clear_votes(vote_dir: str) -> dict:
    """Clear votes for a step (call after applying winner)."""
    votes_file = Path(vote_dir) / "votes.jsonl"
    if votes_file.exists():
        votes_file.unlink()
    return {"cleared": True}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: check_winner.py <vote_dir> [--clear]"}))
        sys.exit(1)
    
    vote_dir = sys.argv[1]
    
    if len(sys.argv) > 2 and sys.argv[2] == "--clear":
        result = clear_votes(vote_dir)
    else:
        result = check_winner(vote_dir)
    
    print(json.dumps(result))
