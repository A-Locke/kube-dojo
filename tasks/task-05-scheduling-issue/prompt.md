# Task: Fix Pod Scheduling — Taint and Toleration

**Namespace:** `cka-task-05`  
**Difficulty:** Medium  
**Topic:** Scheduling, Taints, Tolerations

## Situation

The Deployment `scheduled-app` in namespace `cka-task-05` has pods stuck in `Pending` state.
The pods are not being scheduled onto any node.

## Your Goal

Find out why the pods cannot be scheduled and fix the issue so the pods run.

## Hints

<details>
<summary>Hint 1</summary>
Check pod status and events: `kubectl describe pod <pod-name> -n cka-task-05`
Look for scheduling-related messages in the Events section.
</details>

<details>
<summary>Hint 2</summary>
Inspect node taints: `kubectl describe nodes | grep -A5 Taints`
</details>

<details>
<summary>Hint 3 — Option A: Add a toleration to the Deployment</summary>
Edit the Deployment to add a toleration for the taint:

```yaml
tolerations:
  - key: "env"
    operator: "Equal"
    value: "prod"
    effect: "NoSchedule"
```
</details>

<details>
<summary>Hint 3 — Option B: Remove the taint from nodes</summary>
Remove the taint: `kubectl taint nodes --all env=prod:NoSchedule-`
</details>

## Verification

```powershell
# Windows
.\run.ps1 verify -Task task-05-scheduling-issue
```
```bash
# Linux / macOS
make verify TASK=task-05-scheduling-issue
```
