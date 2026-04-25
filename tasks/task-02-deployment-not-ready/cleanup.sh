#!/usr/bin/env bash
# Task 02: Remove all task resources.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-02"
echo "[cleanup] Deleting namespace ${NS}..."
kubectl delete namespace "${NS}" --ignore-not-found
echo "[cleanup] Done."
