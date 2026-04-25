#!/usr/bin/env bash
# Task 05: Verify that scheduled-app pods are Running.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-05"

DESIRED=$(kubectl get deployment scheduled-app -n "${NS}" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
READY=$(kubectl get deployment scheduled-app -n "${NS}" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

DESIRED="${DESIRED:-0}"
READY="${READY:-0}"

if [ "${READY}" = "${DESIRED}" ] && [ "${DESIRED}" -gt 0 ]; then
  echo "PASS: Deployment 'scheduled-app' is ready (${READY}/${DESIRED} pods running)."
  exit 0
else
  echo "FAIL: Deployment 'scheduled-app' is not ready (ready=${READY}, desired=${DESIRED})."
  echo "      Check pod events: kubectl describe pod -n ${NS} -l app=scheduled-app"
  exit 1
fi
