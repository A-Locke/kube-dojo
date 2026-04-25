#!/usr/bin/env bash
# Task 03: Verify that app-reader ServiceAccount can list pods in cka-task-03.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-03"
SA="app-reader"

CAN=$(kubectl auth can-i list pods \
  --as="system:serviceaccount:${NS}:${SA}" \
  -n "${NS}" 2>/dev/null || echo "no")

if [ "${CAN}" = "yes" ]; then
  echo "PASS: ServiceAccount '${SA}' can list pods in namespace '${NS}'."
  exit 0
else
  echo "FAIL: ServiceAccount '${SA}' cannot list pods in namespace '${NS}'."
  echo "      Create a Role with 'list pods' and bind it to the ServiceAccount."
  exit 1
fi
