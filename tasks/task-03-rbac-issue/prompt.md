# Task: Fix RBAC — ServiceAccount Missing Permissions

**Namespace:** `cka-task-03`  
**Difficulty:** Medium  
**Topic:** RBAC, ServiceAccount, Role, RoleBinding

## Situation

A pod named `pod-lister` in namespace `cka-task-03` uses the ServiceAccount `app-reader`.
The pod is supposed to list pods in the same namespace, but it is failing with
a `Forbidden` error because `app-reader` lacks the required permissions.

## Your Goal

Grant the `app-reader` ServiceAccount permission to list pods in the `cka-task-03` namespace.

You must create:
1. A `Role` that allows `list` on `pods`
2. A `RoleBinding` that binds the Role to the `app-reader` ServiceAccount

## Hints

<details>
<summary>Hint 1</summary>
Check current permissions: `kubectl auth can-i list pods --as=system:serviceaccount:cka-task-03:app-reader -n cka-task-03`
</details>

<details>
<summary>Hint 2</summary>
Create a Role: `kubectl create role pod-reader --verb=list --resource=pods -n cka-task-03`
</details>

<details>
<summary>Hint 3</summary>
Bind the Role: `kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=cka-task-03:app-reader -n cka-task-03`
</details>

## Verification

```powershell
# Windows
.\run.ps1 verify -Task task-03-rbac-issue
```
```bash
# Linux / macOS
make verify TASK=task-03-rbac-issue
```
