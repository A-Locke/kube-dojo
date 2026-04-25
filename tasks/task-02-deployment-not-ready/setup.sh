#!/usr/bin/env bash
# Task 02: Deployment with a non-existent image tag.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-02"

echo "[setup] Creating namespace ${NS}..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "[setup] Creating Deployment with invalid image..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-app
  namespace: ${NS}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-app
  template:
    metadata:
      labels:
        app: api-app
    spec:
      containers:
      - name: api
        image: nginx:this-tag-does-not-exist-99999
        ports:
        - containerPort: 80
EOF

echo "[setup] Task 02 ready. Deployment uses a bad image tag."
