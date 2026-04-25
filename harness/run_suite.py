#!/usr/bin/env python3
"""
CKA Bench — Suite runner.

Runs multiple tasks sequentially and aggregates results.
Each task is run via run_task.py so logs are preserved per-task.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
TASKS_DIR = REPO_ROOT / "tasks"
RUN_TASK = Path(__file__).parent / "run_task.py"
LOGS_DIR = REPO_ROOT / "logs"


def run_task(task_id: str, mode: str, timeout: int) -> dict:
    start = time.time()
    proc = subprocess.run(
        [
            sys.executable,
            str(RUN_TASK),
            "--task",
            task_id,
            "--mode",
            mode,
            "--timeout",
            str(timeout),
        ],
        capture_output=False,
        text=True,
    )
    elapsed = round(time.time() - start, 1)
    return {
        "task": task_id,
        "result": "PASS" if proc.returncode == 0 else "FAIL",
        "elapsed": elapsed,
    }


def main():
    parser = argparse.ArgumentParser(description="Run multiple CKA tasks")
    parser.add_argument("--tasks", nargs="+", help="Task IDs (default: all)")
    parser.add_argument(
        "--mode", choices=["human", "agent", "local"], default="agent"
    )
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()

    if args.tasks:
        task_ids = args.tasks
    else:
        task_ids = sorted(d.name for d in TASKS_DIR.iterdir() if d.is_dir())

    print(f"\nRunning {len(task_ids)} task(s) in '{args.mode}' mode\n")

    results = []
    for task_id in task_ids:
        print(f"\n{'=' * 60}")
        print(f"  Task: {task_id}")
        print(f"{'=' * 60}")
        r = run_task(task_id, args.mode, args.timeout)
        results.append(r)

    # Summary
    passed = sum(1 for r in results if r["result"] == "PASS")
    total = len(results)

    print(f"\n{'=' * 60}")
    print("  SUITE SUMMARY")
    print(f"{'=' * 60}")
    for r in results:
        icon = "PASS" if r["result"] == "PASS" else "FAIL"
        print(f"  [{icon}] {r['task']} ({r['elapsed']}s)")
    print(f"\n  {passed}/{total} tasks passed\n")

    LOGS_DIR.mkdir(exist_ok=True)
    report_path = LOGS_DIR / f"suite_{int(time.time())}.json"
    report_path.write_text(
        json.dumps(
            {
                "mode": args.mode,
                "timestamp": time.time(),
                "passed": passed,
                "total": total,
                "results": results,
            },
            indent=2,
        )
    )
    print(f"  Report: {report_path}\n")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
