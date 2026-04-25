#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[kind] Resetting cluster..."
bash "${SCRIPT_DIR}/destroy_cluster.sh"
bash "${SCRIPT_DIR}/create_cluster.sh"
echo "[kind] Cluster reset complete."
