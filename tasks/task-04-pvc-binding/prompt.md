# Task: Fix PVC Stuck in Pending

**Namespace:** `cka-task-04`  
**Difficulty:** Medium  
**Topic:** Storage, PVC, StorageClass

## Situation

The PersistentVolumeClaim `data-pvc` in namespace `cka-task-04` is stuck in `Pending` state.
A pod is waiting for this PVC before it can start.

## Your Goal

Fix the PVC so it reaches `Bound` state.

## Hints

<details>
<summary>Hint 1</summary>
Inspect the PVC: `kubectl describe pvc data-pvc -n cka-task-04`
Look at the Events section for clues.
</details>

<details>
<summary>Hint 2</summary>
Check what StorageClasses are available: `kubectl get storageclass`
</details>

<details>
<summary>Hint 3</summary>
The PVC requests a StorageClass that does not exist. Delete the PVC and recreate it
using a StorageClass that exists on your cluster (e.g., `standard`).
</details>

## Verification

```powershell
# Windows
.\run.ps1 verify -Task task-04-pvc-binding
```
```bash
# Linux / macOS
make verify TASK=task-04-pvc-binding
```
