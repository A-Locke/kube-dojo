#!/usr/bin/env python3
"""
CKA Bench — Task runner harness.

Orchestrates: setup → solve (human or agent) → verify → log.
"""
import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
TASKS_DIR = REPO_ROOT / "tasks"
SOLVER     = REPO_ROOT / "solver-agent" / "agent.py"
SOLVER_LOCAL = REPO_ROOT / "solver-agent" / "agent_local.sh"
LOGS_DIR = REPO_ROOT / "logs"


def _find_bash() -> str:
    if platform.system() != "Windows":
        return "bash"
    for candidate in [
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files\Git\usr\bin\bash.exe",
        os.path.expandvars(r"%ProgramW6432%\Git\bin\bash.exe"),
    ]:
        if os.path.isfile(candidate):
            return candidate
    found = shutil.which("bash")
    return found if found else "bash"


BASH_EXE = _find_bash()


def run_script(script: Path, capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        [BASH_EXE, str(script)],
        capture_output=capture,
        text=True,
    )


def find_task(task_id: str) -> Path:
    task_dir = TASKS_DIR / task_id
    if not task_dir.exists():
        available = sorted(d.name for d in TASKS_DIR.iterdir() if d.is_dir())
        print(f"ERROR: Task '{task_id}' not found.")
        print(f"Available tasks: {', '.join(available)}")
        sys.exit(1)
    return task_dir


def main():
    parser = argparse.ArgumentParser(description="Run a CKA task")
    parser.add_argument("--task", required=True, help="Task directory name")
    parser.add_argument(
        "--mode",
        choices=["human", "agent", "local"],
        default="human",
        help="human: wait for user; agent: Anthropic API solver; local: claude CLI solver",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Agent timeout in seconds (default: 300)",
    )
    parser.add_argument(
        "--no-setup",
        action="store_true",
        help="Skip setup (task already prepared)",
    )
    args = parser.parse_args()

    task_dir = find_task(args.task)

    LOGS_DIR.mkdir(exist_ok=True)
    log_file = LOGS_DIR / f"{args.task}_{int(time.time())}.json"

    run_log = {
        "task": args.task,
        "mode": args.mode,
        "start_time": time.time(),
        "setup": None,
        "agent": None,
        "verify": None,
        "result": None,
    }

    # --- Setup ---
    if not args.no_setup:
        print(f"\n[harness] Setting up task: {args.task}")
        result = run_script(task_dir / "setup.sh")
        run_log["setup"] = {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
        if result.returncode != 0:
            print("[harness] Setup FAILED:")
            print(result.stderr)
            sys.exit(1)
        print("[harness] Setup complete.\n")
    else:
        print("[harness] Skipping setup (--no-setup).")

    # --- Prompt ---
    prompt_file = task_dir / "prompt.md"
    print("=" * 60)
    print(prompt_file.read_text())
    print("=" * 60 + "\n")

    # --- Solve ---
    if args.mode == "agent":
        print("[harness] Running solver agent (Anthropic API)...")
        agent_proc = subprocess.run(
            [
                sys.executable,
                str(SOLVER),
                "--task-dir",
                str(task_dir),
                "--timeout",
                str(args.timeout),
            ],
            capture_output=False,
            text=True,
        )
        run_log["agent"] = {"returncode": agent_proc.returncode}
    elif args.mode == "local":
        print("[harness] Running local claude CLI solver...")
        agent_proc = subprocess.run(
            [BASH_EXE, str(SOLVER_LOCAL), args.task],
            capture_output=False,
            text=True,
        )
        run_log["agent"] = {"returncode": agent_proc.returncode}
    else:
        print("[harness] Human mode — solve the task, then press Enter to verify.")
        try:
            input()
        except EOFError:
            pass

    # --- Verify ---
    print("[harness] Running verification...")
    verify = run_script(task_dir / "verify.sh")
    run_log["verify"] = {
        "returncode": verify.returncode,
        "stdout": verify.stdout,
        "stderr": verify.stderr,
    }
    passed = verify.returncode == 0
    run_log["result"] = "PASS" if passed else "FAIL"
    run_log["end_time"] = time.time()
    run_log["elapsed"] = round(run_log["end_time"] - run_log["start_time"], 1)

    status_line = "PASS" if passed else "FAIL"
    print(f"\n[harness] {status_line} — {args.task} ({run_log['elapsed']}s)")
    if verify.stdout:
        print(verify.stdout.strip())

    log_file.write_text(json.dumps(run_log, indent=2))
    print(f"[harness] Log: {log_file}")

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
