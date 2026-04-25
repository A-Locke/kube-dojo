#!/usr/bin/env bash
# Task 01: Broken Service Routing
# Injects a Service whose selector does not match the Deployment's pod labels.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-01"

echo "[setup] Creating namespace ${NS}..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "[setup] Creating Deployment and misconfigured Service..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-backend
  namespace: ${NS}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-backend
  template:
    metadata:
      labels:
        app: web-backend
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: ${NS}
spec:
  selector:
    app: web-frontend
  ports:
  - port: 80
    targetPort: 80
EOF

echo "[setup] Task 01 ready. Service selector is intentionally wrong."
