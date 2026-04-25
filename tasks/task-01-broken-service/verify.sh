#!/usr/bin/env bash
# Task 01: Verify that web-service has active endpoints.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-01"

ENDPOINTS=$(kubectl get endpoints web-service -n "${NS}" \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")

if [ -z "${ENDPOINTS}" ] || [ "${ENDPOINTS}" = "null" ]; then
  echo "FAIL: Service 'web-service' in namespace '${NS}' has no endpoints."
  echo "      The selector likely still does not match any pod labels."
  exit 1
fi

echo "PASS: Service 'web-service' has active endpoints."
exit 0
