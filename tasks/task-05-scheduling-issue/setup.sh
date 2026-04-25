#!/usr/bin/env bash
# Task 05: Taint worker nodes so Deployment pods cannot be scheduled.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-05"

echo "[setup] Creating namespace ${NS}..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "[setup] Adding taint to all schedulable nodes..."
for node in $(kubectl get nodes --no-headers -o name 2>/dev/null); do
  kubectl taint node "${node}" env=prod:NoSchedule --overwrite
  echo "  Tainted: ${node}"
done

echo "[setup] Creating Deployment without tolerations..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scheduled-app
  namespace: ${NS}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: scheduled-app
  template:
    metadata:
      labels:
        app: scheduled-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF

echo "[setup] Task 05 ready. Worker nodes are tainted; pods will be Pending."
