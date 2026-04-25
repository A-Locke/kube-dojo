#!/usr/bin/env bash
# Task 05: Remove taint and delete task resources.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-05"

echo "[cleanup] Removing taint from all nodes..."
for node in $(kubectl get nodes --no-headers -o name 2>/dev/null); do
  kubectl taint node "${node}" env=prod:NoSchedule- 2>/dev/null || true
  echo "  Untainted: ${node}"
done

echo "[cleanup] Deleting namespace ${NS}..."
kubectl delete namespace "${NS}" --ignore-not-found
echo "[cleanup] Done."
