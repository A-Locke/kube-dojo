#!/usr/bin/env python3
"""
CKA Bench — Killercoda scenario generator.

Reads a task directory and emits a complete Killercoda scenario under
adapters/killercoda/scenarios/<task-id>/.

Generated layout:
  <task-id>/
    index.json
    intro.md
    finish.md
    foreground.sh          (clones repo + runs setup.sh)
    step1/
      text.md              (the task prompt)
      verify.sh            (wraps task verify.sh)

Usage:
  python3 generate_scenario.py task-01-broken-service
  python3 generate_scenario.py all
"""
import json
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore

REPO_ROOT = Path(__file__).parent.parent.parent
TASKS_DIR = REPO_ROOT / "tasks"
SCENARIOS_DIR = Path(__file__).parent / "scenarios"


def _load_env() -> dict:
    """Load key=value pairs from .env in the repo root."""
    env = {}
    env_file = REPO_ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env


_ENV = _load_env()


def _get(key: str, fallback: str = "") -> str:
    return os.environ.get(key) or _ENV.get(key) or fallback


REPO_URL = _get("KUBE_DOJO_REPO_URL")
if not REPO_URL:
    print(
        "WARNING: KUBE_DOJO_REPO_URL not set. "
        "Add it to .env or set the environment variable before generating scenarios.\n"
        "  Example: KUBE_DOJO_REPO_URL=https://github.com/your-org/kube-dojo\n"
        "The generated foreground.sh will contain a placeholder URL.",
        file=sys.stderr,
    )
    REPO_URL = "https://github.com/your-org/kube-dojo"

KILLERCODA_SCENARIOS_DIR = _get("KILLERCODA_SCENARIOS_DIR")
DEFAULT_OUTPUT = Path(KILLERCODA_SCENARIOS_DIR) if KILLERCODA_SCENARIOS_DIR else SCENARIOS_DIR


def load_metadata(task_dir: Path) -> dict:
    meta_file = task_dir / "metadata.yaml"
    if not meta_file.exists():
        return {}
    if yaml is None:
        # Minimal YAML parser for simple key: value files
        meta = {}
        for line in meta_file.read_text().splitlines():
            if ":" in line and not line.startswith("#"):
                k, _, v = line.partition(":")
                meta[k.strip()] = v.strip()
        return meta
    with open(meta_file) as f:
        return yaml.safe_load(f) or {}


def generate_scenario(task_id: str, output_base: Path = SCENARIOS_DIR) -> Path:
    task_dir = TASKS_DIR / task_id
    if not task_dir.exists():
        raise FileNotFoundError(f"Task directory not found: {task_dir}")

    meta = load_metadata(task_dir)
    title = meta.get("title", task_id)
    description = meta.get("description", "")
    difficulty = meta.get("difficulty", "intermediate")

    scenario_dir = output_base / task_id
    step_dir = scenario_dir / "step1"
    step_dir.mkdir(parents=True, exist_ok=True)

    # index.json
    index = {
        "title": title,
        "description": description,
        "difficulty": difficulty,
        "time": "15",
        "details": {
            "steps": [
                {
                    "title": "Solve the Task",
                    "text": "step1/text.md",
                    "verify": "step1/verify.sh",
                    "courseData": "foreground.sh",
                }
            ],
            "intro": {
                "text": "intro.md",
                "courseData": "foreground.sh",
            },
            "finish": {
                "text": "finish.md",
            },
        },
        "backend": {
            "imageid": "kubernetes-kubeadm-1node",
        },
    }
    (scenario_dir / "index.json").write_text(json.dumps(index, indent=2) + "\n")

    # step1/text.md — the task prompt
    prompt = (task_dir / "prompt.md").read_text()
    (step_dir / "text.md").write_text(prompt)

    # step1/verify.sh — wraps the shared task verify.sh
    verify_sh = f"""\
#!/bin/bash
# Killercoda verify step for: {task_id}
set -euo pipefail
TASK_DIR="/root/cka-bench/tasks/{task_id}"
bash "${{TASK_DIR}}/verify.sh"
"""
    verify_path = step_dir / "verify.sh"
    verify_path.write_text(verify_sh)

    # foreground.sh — clones repo and runs setup
    foreground_sh = f"""\
#!/bin/bash
# Killercoda foreground setup for: {task_id}
set -euo pipefail

REPO_URL="${{REPO_URL:-{REPO_URL}}}"
REPO_DIR="/root/cka-bench"
TASK_DIR="${{REPO_DIR}}/tasks/{task_id}"

if [ ! -d "${{REPO_DIR}}" ]; then
  echo "[setup] Cloning repo..."
  git clone "${{REPO_URL}}" "${{REPO_DIR}}"
fi

echo "[setup] Preparing task: {task_id}"
bash "${{TASK_DIR}}/setup.sh"
echo "[setup] Done. Read Step 1 for instructions."
"""
    fg_path = scenario_dir / "foreground.sh"
    fg_path.write_text(foreground_sh)

    # intro.md
    intro_md = f"""\
# {title}

**Difficulty:** {difficulty}

The environment is being prepared. This may take a moment.

Once ready, proceed to **Step 1** to read the task description.
"""
    (scenario_dir / "intro.md").write_text(intro_md)

    # finish.md
    finish_md = """\
# Well Done!

You successfully completed this CKA-style task.

Keep practising to build confidence for the real exam.
"""
    (scenario_dir / "finish.md").write_text(finish_md)

    print(f"[generate] Scenario written: {scenario_dir}")
    return scenario_dir


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Generate Killercoda scenarios")
    parser.add_argument(
        "task",
        help="Task ID to generate, or 'all' to generate every task",
    )
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help="Output directory (default: KILLERCODA_SCENARIOS_DIR from .env, or adapters/killercoda/scenarios/)",
    )
    args = parser.parse_args()

    output_dir = Path(args.output)

    if args.task == "all":
        task_ids = sorted(d.name for d in TASKS_DIR.iterdir() if d.is_dir())
        if not task_ids:
            print("No tasks found.")
            sys.exit(1)
        for tid in task_ids:
            generate_scenario(tid, output_dir)
    else:
        generate_scenario(args.task, output_dir)


if __name__ == "__main__":
    main()
