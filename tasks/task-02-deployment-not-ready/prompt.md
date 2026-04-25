# Task: Fix Deployment With Bad Image

**Namespace:** `cka-task-02`  
**Difficulty:** Easy  
**Topic:** Deployments, Container Images

## Situation

The Deployment `api-app` in namespace `cka-task-02` has 0 ready replicas.
The pods are stuck and not starting correctly.

## Your Goal

Find out why the pods are not starting and fix the Deployment so that
all replicas become Ready.

## Hints

<details>
<summary>Hint 1</summary>
Check the pod status: `kubectl get pods -n cka-task-02`
</details>

<details>
<summary>Hint 2</summary>
Describe a failing pod to see the error: `kubectl describe pod <pod-name> -n cka-task-02`
</details>

<details>
<summary>Hint 3</summary>
The container image tag is invalid. Update the Deployment to use a valid image.
Run: `kubectl set image deployment/api-app api=nginx:1.25 -n cka-task-02`
</details>

## Verification

```powershell
# Windows
.\run.ps1 verify -Task task-02-deployment-not-ready
```
```bash
# Linux / macOS
make verify TASK=task-02-deployment-not-ready
```
