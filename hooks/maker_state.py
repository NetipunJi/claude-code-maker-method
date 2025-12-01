#!/usr/bin/env python3
"""
MAKER Framework - State Persistence
Tracks execution progress and enables resume capability
"""

import json
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional


class MAKERState:
    """Manages state persistence for MAKER task execution."""

    def __init__(self, session_id: str, state_dir: str = "/tmp/maker-state"):
        self.session_id = session_id
        self.state_dir = Path(state_dir) / session_id
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.state_file = self.state_dir / "execution.json"
        self.metrics_file = self.state_dir / "metrics.jsonl"

    def initialize(self, total_steps: int, task_description: str, k: int = 3) -> Dict:
        """Initialize new execution state."""
        state = {
            "session_id": self.session_id,
            "task_description": task_description,
            "total_steps": total_steps,
            "k": k,
            "started_at": datetime.now().isoformat(),
            "status": "in_progress",
            "current_step": 0,
            "steps": {},
            "metrics": {
                "total_votes_cast": 0,
                "red_flags": 0,
                "completed_steps": 0,
                "failed_steps": 0
            }
        }
        self._save_state(state)
        return state

    def load(self) -> Optional[Dict]:
        """Load existing state."""
        if not self.state_file.exists():
            return None
        return json.loads(self.state_file.read_text())

    def update_step(self, step_id: str, status: str, winner: Optional[Dict] = None,
                   votes: int = 0, margin: int = 0, red_flags: int = 0) -> Dict:
        """Update state for a specific step."""
        state = self.load() or {}

        if "steps" not in state:
            state["steps"] = {}

        step_data = {
            "step_id": step_id,
            "status": status,  # "voting", "decided", "failed"
            "votes": votes,
            "margin": margin,
            "red_flags": red_flags,
            "winner": winner,
            "updated_at": datetime.now().isoformat()
        }

        state["steps"][step_id] = step_data

        # Update metrics
        if status == "decided":
            state["metrics"]["completed_steps"] = state["metrics"].get("completed_steps", 0) + 1
            state["current_step"] = len([s for s in state["steps"].values() if s["status"] == "decided"])
        elif status == "failed":
            state["metrics"]["failed_steps"] = state["metrics"].get("failed_steps", 0) + 1

        state["metrics"]["total_votes_cast"] = state["metrics"].get("total_votes_cast", 0) + votes
        state["metrics"]["red_flags"] = state["metrics"].get("red_flags", 0) + red_flags

        self._save_state(state)
        self._log_metric(step_data)
        return state

    def get_k_value(self) -> int:
        """Get the k value for this session."""
        state = self.load()
        if not state:
            return 3  # Default fallback
        return state.get("k", 3)

    def get_resume_point(self) -> Optional[Dict]:
        """Get information about where to resume execution."""
        state = self.load()
        if not state:
            return None

        completed = [s for s in state.get("steps", {}).values() if s["status"] == "decided"]
        total = state.get("total_steps", 0)

        return {
            "completed_steps": len(completed),
            "total_steps": total,
            "next_step": len(completed) + 1,
            "can_resume": len(completed) < total and state.get("status") == "in_progress"
        }

    def mark_complete(self, success: bool = True) -> Dict:
        """Mark execution as complete."""
        state = self.load() or {}
        state["status"] = "success" if success else "failed"
        state["completed_at"] = datetime.now().isoformat()
        self._save_state(state)
        return state

    def generate_report(self) -> str:
        """Generate execution report."""
        state = self.load()
        if not state:
            return "No state found"

        lines = [
            "MAKER Execution Report",
            "=" * 50,
            f"Session: {state.get('session_id', 'unknown')}",
            f"Task: {state.get('task_description', 'N/A')}",
            f"Status: {state.get('status', 'unknown')}",
            "",
            f"Total steps: {state.get('total_steps', 0)}",
            f"Completed: {state['metrics'].get('completed_steps', 0)}",
            f"Failed: {state['metrics'].get('failed_steps', 0)}",
            f"Total votes cast: {state['metrics'].get('total_votes_cast', 0)}",
            f"Red-flagged votes: {state['metrics'].get('red_flags', 0)}",
            "",
            "Step Details:",
            "-" * 50
        ]

        for step_id, step in sorted(state.get("steps", {}).items()):
            status_icon = "✓" if step["status"] == "decided" else "✗"
            lines.append(
                f"{status_icon} {step_id}: "
                f"votes={step.get('votes', 0)}, "
                f"margin={step.get('margin', 0)}, "
                f"red_flags={step.get('red_flags', 0)}"
            )

        if state.get("started_at"):
            lines.append("")
            lines.append(f"Started: {state['started_at']}")
            if state.get("completed_at"):
                lines.append(f"Completed: {state['completed_at']}")

        return "\n".join(lines)

    def _save_state(self, state: Dict):
        """Save state to disk."""
        self.state_file.write_text(json.dumps(state, indent=2))

    def _log_metric(self, metric: Dict):
        """Append metric to log."""
        with open(self.metrics_file, "a") as f:
            f.write(json.dumps(metric) + "\n")


def main():
    """CLI interface for state management."""
    if len(sys.argv) < 3:
        print(json.dumps({
            "error": "Usage: maker_state.py <session_id> <command> [args...]",
            "commands": {
                "init": "maker_state.py <session_id> init <total_steps> <task_desc> [k]",
                "update": "maker_state.py <session_id> update <step_id> <status> [winner_json] [votes] [margin] [red_flags]",
                "load": "maker_state.py <session_id> load",
                "get-k": "maker_state.py <session_id> get-k",
                "resume": "maker_state.py <session_id> resume",
                "report": "maker_state.py <session_id> report",
                "complete": "maker_state.py <session_id> complete [success]"
            }
        }))
        sys.exit(1)

    session_id = sys.argv[1]
    command = sys.argv[2]
    state = MAKERState(session_id)

    try:
        if command == "init":
            total_steps = int(sys.argv[3])
            task_desc = sys.argv[4]
            k = int(sys.argv[5]) if len(sys.argv) > 5 else 3
            result = state.initialize(total_steps, task_desc, k)
            print(json.dumps(result))

        elif command == "update":
            step_id = sys.argv[3]
            status = sys.argv[4]
            winner = json.loads(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] != "null" else None
            votes = int(sys.argv[6]) if len(sys.argv) > 6 else 0
            margin = int(sys.argv[7]) if len(sys.argv) > 7 else 0
            red_flags = int(sys.argv[8]) if len(sys.argv) > 8 else 0
            result = state.update_step(step_id, status, winner, votes, margin, red_flags)
            print(json.dumps(result))

        elif command == "load":
            result = state.load()
            print(json.dumps(result))

        elif command == "get-k":
            k = state.get_k_value()
            print(json.dumps({"k": k}))

        elif command == "resume":
            result = state.get_resume_point()
            print(json.dumps(result))

        elif command == "report":
            report = state.generate_report()
            print(report)

        elif command == "complete":
            success = sys.argv[3].lower() == "true" if len(sys.argv) > 3 else True
            result = state.mark_complete(success)
            print(json.dumps(result))

        else:
            print(json.dumps({"error": f"Unknown command: {command}"}))
            sys.exit(1)

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
