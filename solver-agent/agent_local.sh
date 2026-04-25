#!/usr/bin/env bash
# solver-agent/agent_local.sh
#
# Runs the solver using the locally installed 'claude' CLI.
# No ANTHROPIC_API_KEY required — uses Claude Code's existing authentication.
#
# Usage:
#   bash solver-agent/agent_local.sh task-01-broken-service
#   make solve-local TASK=task-01-broken-service
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

TASK="${1:-}"
if [ -z "${TASK}" ]; then
  echo "Usage: $0 <task-id>"
  echo ""
  echo "Available tasks:"
  ls tasks/
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_DIR="${REPO_ROOT}/tasks/${TASK}"

if [ ! -d "${TASK_DIR}" ]; then
  echo "ERROR: Task not found: ${TASK}"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH."
  echo "Install Claude Code from https://claude.ai/code and ensure the CLI is on your PATH."
  exit 1
fi

PROMPT="$(cat <<PROMPT
Solve this CKA bench task: ${TASK}

$(cat "${TASK_DIR}/prompt.md")

Working directory: ${REPO_ROOT}

Think out loud at every step. Before each command, explain what you are about to run
and what you expect to learn. After each command, explain what the output tells you.
This is a learning environment — the explanation matters as much as the fix.

Instructions:
1. Explain the task in your own words before doing anything.
2. If the task namespace does not yet exist, run: bash ${TASK_DIR}/setup.sh — explain what it sets up.
3. Inspect the cluster with kubectl. Before each command, state why you are running it. After each result, state what you now know.
4. Explain the root cause in plain terms before making any change.
5. Describe what change you are about to make and why, then apply it.
6. Run: bash ${TASK_DIR}/verify.sh — explain what it is checking.
7. If verify exits non-zero, explain why the fix did not work, then inspect and try again.
8. When verify passes, give a final summary: what was broken, what you fixed, what the verify step confirmed.
PROMPT
)"

echo "[local-agent] Task:  ${TASK}"
echo "[local-agent] Mode:  claude CLI (no API key required)"
echo "[local-agent] Starting..."
echo ""

printf '%s' "${PROMPT}" | claude --print --allowedTools "Bash"
