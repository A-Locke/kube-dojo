#!/usr/bin/env bash
# prep-env/stop.sh — Destroy the local kind cluster entirely.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "${REPO_ROOT}/adapters/local-kind/destroy_cluster.sh"
