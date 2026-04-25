# Task: Fix Broken Service Routing

**Namespace:** `cka-task-01`  
**Difficulty:** Easy  
**Topic:** Services, Selectors

## Situation

The service `web-service` in namespace `cka-task-01` is not routing traffic to any pods.
A Deployment named `web-backend` is running, but the Service has zero endpoints.

## Your Goal

Identify why `web-service` has no endpoints and fix it so the Service routes traffic
to the pods from the `web-backend` Deployment.

## Hints

<details>
<summary>Hint 1</summary>
Check the Service selector and compare it with the pod labels.
</details>

<details>
<summary>Hint 2</summary>
Use `kubectl describe service web-service -n cka-task-01` and
`kubectl get pods -n cka-task-01 --show-labels` to compare.
</details>

<details>
<summary>Hint 3</summary>
Edit the Service with `kubectl edit service web-service -n cka-task-01` and
fix the `selector` field to match the pod labels.
</details>

## Verification

```powershell
# Windows
.\run.ps1 verify -Task task-01-broken-service
```
```bash
# Linux / macOS
make verify TASK=task-01-broken-service
```
