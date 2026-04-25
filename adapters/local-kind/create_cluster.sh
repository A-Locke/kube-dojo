#!/usr/bin/env bash
set -euo pipefail

# On Windows, WinGet-installed binaries land in a directory not on Git Bash PATH.
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

CLUSTER_NAME="${CLUSTER_NAME:-cka-bench}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIND_CONFIG="${SCRIPT_DIR}/kind-config.yaml"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[kind] Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
  kind export kubeconfig --name "${CLUSTER_NAME}"
  kubectl config use-context "kind-${CLUSTER_NAME}"
  exit 0
fi

echo "[kind] Creating cluster '${CLUSTER_NAME}'..."
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}" --wait 60s

echo "[kind] Exporting kubeconfig..."
kind export kubeconfig --name "${CLUSTER_NAME}"
kubectl config use-context "kind-${CLUSTER_NAME}"

echo "[kind] Cluster ready. Context: kind-${CLUSTER_NAME}"
kubectl get nodes
