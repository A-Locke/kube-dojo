#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

CLUSTER_NAME="${CLUSTER_NAME:-cka-bench}"

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[kind] Cluster '${CLUSTER_NAME}' does not exist. Nothing to destroy."
  exit 0
fi

echo "[kind] Destroying cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

# kind delete cluster does not remove kubeconfig context/cluster entries — clean them up.
CTX="kind-${CLUSTER_NAME}"
echo "[kind] Cleaning up kubeconfig context '${CTX}'..."
kubectl config delete-context "${CTX}" 2>/dev/null || true
kubectl config delete-cluster "${CTX}" 2>/dev/null || true
echo "[kind] Done."
