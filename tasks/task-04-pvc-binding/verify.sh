#!/usr/bin/env bash
# Task 04: Verify that data-pvc is Bound.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-04"

PVC_STATUS=$(kubectl get pvc data-pvc -n "${NS}" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

POD_STATUS=$(kubectl get pod data-consumer -n "${NS}" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

PASS=true

if [ "${PVC_STATUS}" != "Bound" ]; then
  echo "FAIL: PVC 'data-pvc' status is '${PVC_STATUS}', expected 'Bound'."
  echo "      Delete and recreate it using a StorageClass that exists: kubectl get storageclass"
  PASS=false
fi

if [ "${POD_STATUS}" != "Running" ]; then
  echo "FAIL: Pod 'data-consumer' status is '${POD_STATUS}', expected 'Running'."
  PASS=false
fi

if [ "${PASS}" = "true" ]; then
  echo "PASS: PVC 'data-pvc' is Bound and pod 'data-consumer' is Running."
  exit 0
else
  exit 1
fi
