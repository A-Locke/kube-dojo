#!/usr/bin/env bash
# Task 04: PVC requesting a non-existent StorageClass.
set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
fi

NS="cka-task-04"

echo "[setup] Creating namespace ${NS}..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "[setup] Creating PVC with non-existent StorageClass..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: ${NS}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: fast-ssd
EOF

echo "[setup] Creating pod that waits for the PVC..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-consumer
  namespace: ${NS}
spec:
  containers:
  - name: app
    image: nginx:1.25
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
EOF

echo "[setup] Task 04 ready. PVC 'data-pvc' requests StorageClass 'fast-ssd' which does not exist."
