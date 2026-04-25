#!/usr/bin/env bash
# Task 02: Verify that api-app deployment is fully ready.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-02"

READY=$(kubectl get deployment api-app -n "${NS}" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get deployment api-app -n "${NS}" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

READY="${READY:-0}"
DESIRED="${DESIRED:-0}"

if [ "${READY}" = "${DESIRED}" ] && [ "${DESIRED}" -gt 0 ]; then
  echo "PASS: Deployment 'api-app' is ready (${READY}/${DESIRED} replicas)."
  exit 0
else
  echo "FAIL: Deployment 'api-app' is not ready (ready=${READY}, desired=${DESIRED})."
  exit 1
fi
