#!/usr/bin/env bash
# Task 03: ServiceAccount missing RBAC permissions.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-03"

echo "[setup] Creating namespace ${NS}..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "[setup] Creating ServiceAccount and Deployment without RBAC..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: ${NS}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-lister
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pod-lister
  template:
    metadata:
      labels:
        app: pod-lister
    spec:
      serviceAccountName: app-reader
      containers:
      - name: kubectl
        image: bitnami/kubectl:1.28
        command:
          - sh
          - -c
          - |
            while true; do
              echo "--- listing pods ---"
              kubectl get pods -n ${NS} || true
              sleep 10
            done
EOF

echo "[setup] Task 03 ready. ServiceAccount 'app-reader' has no RBAC permissions."
