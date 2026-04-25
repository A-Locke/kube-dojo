# Task Authoring Guide

## Task contract

Every task lives under `tasks/<task-id>/` and must contain exactly these files:

```
tasks/<task-id>/
  prompt.md       ← shown to human or agent
  setup.sh        ← injects broken state
  verify.sh       ← deterministic pass/fail (exit 0 = PASS)
  cleanup.sh      ← removes task resources
  metadata.yaml   ← machine-readable task metadata
```

---

## Naming convention

Use `task-NN-short-slug` format. Examples:
- `task-06-missing-configmap`
- `task-07-node-not-ready`

The numeric prefix ensures consistent ordering.

---

## metadata.yaml

```yaml
id: task-06-missing-configmap
title: "Fix Missing ConfigMap Reference"
description: "A Deployment references a ConfigMap that does not exist. Fix it."
difficulty: easy          # easy | medium | hard
topic: configmaps
namespace: cka-task-06
requirements:
  - kubectl
  - knowledge of ConfigMaps and environment variables
estimated_minutes: 10
```

---

## setup.sh rules

- **MUST** assume the cluster already exists. Do not call `kind` or create clusters.
- **MUST** use `kubectl` only.
- **MUST** be idempotent (running it twice should not cause errors). Use `--dry-run=client -o yaml | kubectl apply -f -` for namespace creation.
- **MUST** inject a clearly broken or incomplete state.
- **SHOULD** use a dedicated namespace `cka-task-NN` to isolate resources.
- **SHOULD** print a brief summary of what was set up.

```bash
#!/usr/bin/env bash
set -euo pipefail

NS="cka-task-06"
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
# ... broken state here
EOF

echo "[setup] Task 06 ready."
```

---

## verify.sh rules

- **MUST** exit 0 on success, non-zero on failure.
- **MUST** be deterministic — no randomness, no LLM calls.
- **MUST** print a clear PASS or FAIL message.
- **SHOULD** print a diagnostic hint on failure.
- **SHOULD** check observable Kubernetes state, not implementation details.

```bash
#!/usr/bin/env bash
set -euo pipefail

NS="cka-task-06"
STATUS=$(kubectl get deployment my-app -n "${NS}" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "${STATUS:-0}" -ge 1 ]; then
  echo "PASS: Deployment is ready."
  exit 0
else
  echo "FAIL: Deployment is not ready."
  exit 1
fi
```

---

## cleanup.sh rules

- **MUST** remove all resources created by setup.sh.
- **SHOULD** use `--ignore-not-found` to be safe when run multiple times.
- **SHOULD** remove any node-level changes (taints, labels) applied during setup.

```bash
#!/usr/bin/env bash
set -euo pipefail

kubectl delete namespace cka-task-06 --ignore-not-found
```

---

## prompt.md guidelines

- Start with a brief **Situation** paragraph describing what is broken.
- State the **Goal** clearly and specifically.
- Include collapsed **Hints** using `<details>` blocks — not shown by default.
- End with the verification command.

Template:

```markdown
# Task: <title>

**Namespace:** `cka-task-NN`
**Difficulty:** Easy | Medium | Hard
**Topic:** <topic>

## Situation
<what is currently broken>

## Your Goal
<what the human or agent must achieve>

## Hints

<details>
<summary>Hint 1</summary>
...
</details>

## Verification
\`\`\`bash
make verify TASK=task-NN-slug
\`\`\`
```

---

## Testing a new task

```bash
# 1. Ensure cluster is up
make cluster-create

# 2. Setup the task
bash tasks/task-NN-slug/setup.sh

# 3. Manually verify the broken state
kubectl get all -n cka-task-NN

# 4. Apply the fix manually
# ...

# 5. Run verify
bash tasks/task-NN-slug/verify.sh

# 6. Cleanup
bash tasks/task-NN-slug/cleanup.sh

# 7. Confirm cleanup
kubectl get ns cka-task-NN   # should return NotFound
```

---

## Difficulty guidelines

| Difficulty | Characteristics |
|---|---|
| Easy | Single misconfiguration, obvious from `kubectl describe` |
| Medium | Requires understanding of 2+ Kubernetes concepts, some diagnosis |
| Hard | Multiple interacting issues, requires cross-resource reasoning |
