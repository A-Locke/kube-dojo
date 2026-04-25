#!/usr/bin/env python3
"""
CKA Bench — Solver Agent

A ReAct-style agent that reads a task prompt, inspects the Kubernetes cluster
via kubectl, and iteratively fixes the issue until verify.sh passes or timeout.

Requires: pip install anthropic
Set ANTHROPIC_API_KEY in your environment.
"""
import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path


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
_WINGET_PREFIX = (
    'export PATH="$HOME/AppData/Local/Microsoft/WinGet/Links:$PATH"; '
    if platform.system() == "Windows"
    else ""
)

try:
    import anthropic
except ImportError:
    print("ERROR: anthropic package not installed. Run: pip install anthropic")
    sys.exit(1)

TOOLS = [
    {
        "name": "kubectl",
        "description": (
            "Run a kubectl command against the Kubernetes cluster. "
            "Do not include the 'kubectl' prefix — just the subcommand and flags. "
            "Example input: 'get pods -n cka-task-01 --show-labels'"
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "args": {
                    "type": "string",
                    "description": "kubectl arguments (everything after 'kubectl')",
                }
            },
            "required": ["args"],
        },
    },
    {
        "name": "bash",
        "description": (
            "Run a shell command. Use for piping kubectl output through jq, "
            "grep, awk, or constructing multi-step commands. "
            "kubectl, jq, and standard POSIX tools are available."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Shell command to execute",
                }
            },
            "required": ["command"],
        },
    },
]

SYSTEM_PROMPT = """\
You are a CKA (Certified Kubernetes Administrator) exam solver agent.

Your job is to diagnose and fix Kubernetes issues by interacting with the cluster
through kubectl and bash. You must behave like a human CKA candidate at a terminal.

## Approach
1. Read the task prompt carefully.
2. Inspect the relevant resources to understand the broken state.
3. Form a hypothesis about what is wrong.
4. Apply a targeted fix using kubectl.
5. Confirm the fix worked by checking the resource state again.
6. When confident the task is solved, say DONE.

## Rules
- Only use kubectl and bash.
- Do not take shortcuts that bypass normal kubectl workflows.
- Be systematic: inspect first, then fix.
- After applying a fix, verify it actually worked before claiming success.
- If a fix did not work, try a different approach.
"""


def run_command(cmd: str, timeout: int = 30) -> dict:
    try:
        result = subprocess.run(
            [BASH_EXE, "-c", _WINGET_PREFIX + cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "returncode": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {"stdout": "", "stderr": "Command timed out", "returncode": -1}
    except Exception as exc:
        return {"stdout": "", "stderr": str(exc), "returncode": -1}


def execute_tool(tool_name: str, tool_input: dict) -> str:
    if tool_name == "kubectl":
        result = run_command(f"kubectl {tool_input['args']}")
    elif tool_name == "bash":
        result = run_command(tool_input["command"])
    else:
        return f"Unknown tool: {tool_name}"

    parts = []
    if result["stdout"]:
        parts.append(result["stdout"])
    if result["stderr"]:
        parts.append(f"[stderr] {result['stderr']}")
    if result["returncode"] != 0:
        parts.append(f"[exit {result['returncode']}]")
    return "\n".join(parts) if parts else "(no output)"


def main():
    parser = argparse.ArgumentParser(description="CKA solver agent")
    parser.add_argument("--task-dir", required=True, help="Path to task directory")
    parser.add_argument(
        "--timeout", type=int, default=300, help="Max seconds to spend (default: 300)"
    )
    parser.add_argument(
        "--model",
        default="claude-opus-4-7",
        help="Anthropic model to use (default: claude-opus-4-7)",
    )
    args = parser.parse_args()

    task_dir = Path(args.task_dir)
    if not task_dir.exists():
        print(f"ERROR: task-dir not found: {task_dir}")
        sys.exit(1)

    prompt = (task_dir / "prompt.md").read_text()
    verify_script = task_dir / "verify.sh"

    client = anthropic.Anthropic()

    messages = [
        {
            "role": "user",
            "content": (
                f"Solve this Kubernetes task:\n\n{prompt}\n\n"
                "Inspect the cluster, find the problem, and fix it. "
                "When you are confident the issue is resolved, say DONE."
            ),
        }
    ]

    print(f"[agent] Model: {args.model}")
    print(f"[agent] Task: {task_dir.name}")
    print(f"[agent] Timeout: {args.timeout}s")

    start = time.time()
    max_iterations = 25

    for iteration in range(1, max_iterations + 1):
        elapsed = time.time() - start
        if elapsed >= args.timeout:
            print(f"\n[agent] Timeout reached ({args.timeout}s). Stopping.")
            break

        print(f"\n[agent] --- Iteration {iteration} ---")

        response = client.messages.create(
            model=args.model,
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        assistant_content = list(response.content)
        tool_results = []
        done = False

        for block in response.content:
            if block.type == "text":
                text = block.text.strip()
                if text:
                    print(f"[agent] {text}")
                if "DONE" in text.upper():
                    done = True
            elif block.type == "tool_use":
                print(f"[agent] {block.name}({block.input})")
                output = execute_tool(block.name, block.input)
                preview = output[:300] + ("..." if len(output) > 300 else "")
                print(f"[agent] → {preview}")
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": output,
                    }
                )

        messages.append({"role": "assistant", "content": assistant_content})
        if tool_results:
            messages.append({"role": "user", "content": tool_results})

        if done or response.stop_reason == "end_turn":
            break

    # Final verification
    print("\n[agent] Running final verification...")
    verify = subprocess.run(
        [BASH_EXE, str(verify_script)], capture_output=True, text=True
    )
    if verify.stdout:
        print(verify.stdout.strip())

    if verify.returncode == 0:
        print("[agent] PASS — task solved!")
        sys.exit(0)
    else:
        print("[agent] FAIL — task not solved.")
        sys.exit(1)


if __name__ == "__main__":
    main()
