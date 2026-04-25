#!/usr/bin/env bash
# prep-env/start.sh — Set up a task on the local kind cluster (human mode).
set -euo pipefail

# On Windows, WinGet-installed binaries land in a directory not on Git Bash PATH.
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

TASK="${1:-}"
CLUSTER_NAME="${CLUSTER_NAME:-cka-bench}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${TASK}" ]; then
  echo "Usage: $0 <task-id>"
  echo ""
  echo "Available tasks:"
  ls "${REPO_ROOT}/tasks/"
  exit 1
fi

TASK_DIR="${REPO_ROOT}/tasks/${TASK}"
if [ ! -d "${TASK_DIR}" ]; then
  echo "ERROR: Task not found: ${TASK}"
  echo "Available tasks:"
  ls "${REPO_ROOT}/tasks/"
  exit 1
fi

# Ensure kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[prep] Kind cluster '${CLUSTER_NAME}' not found. Creating it..."
  bash "${REPO_ROOT}/adapters/local-kind/create_cluster.sh"
fi

# Set kubectl context
kubectl config use-context "kind-${CLUSTER_NAME}" 2>/dev/null || true

# Run task setup
echo "[prep] Setting up task: ${TASK}"
bash "${TASK_DIR}/setup.sh"

# Print prompt
echo ""
echo "================================================================"
echo "  TASK: ${TASK}"
echo "================================================================"
cat "${TASK_DIR}/prompt.md"
echo "================================================================"
echo ""
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  echo "When you are done, run:"
  echo "  .\\run.ps1 verify -Task ${TASK}"
  echo ""
  echo "To clean up:"
  echo "  .\\run.ps1 clean -Task ${TASK}"
else
  echo "When you are done, run:"
  echo "  make verify TASK=${TASK}"
  echo ""
  echo "To clean up:"
  echo "  make clean TASK=${TASK}"
fi
