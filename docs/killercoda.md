# Killercoda Deployment Guide

## Overview

Any task in `tasks/` can be published as a Killercoda browser-based scenario.
The Killercoda adapter generates all necessary scenario files from the shared task definition.

The cluster is **not** created by the scenario — Killercoda provides a pre-built
Kubernetes environment (`kubernetes-kubeadm-1node`). The scenario only runs `setup.sh`
against that existing cluster.

---

## Generate scenario files

Single task:
```bash
make scenario TASK=task-01-broken-service
```

All tasks:
```bash
make scenario TASK=all
```

Output directory: `adapters/killercoda/scenarios/<task-id>/`

---

## Generated file layout

```
adapters/killercoda/scenarios/task-01-broken-service/
  index.json          scenario metadata and step structure
  intro.md            shown before the scenario starts
  finish.md           shown when all steps pass
  foreground.sh       clones repo + runs setup.sh
  step1/
    text.md           the task prompt (= tasks/.../prompt.md)
    verify.sh         wraps tasks/.../verify.sh
```

---

## index.json

The generator produces an `index.json` using the `kubernetes-kubeadm-1node` backend.

```json
{
  "title": "Fix Broken Service Routing",
  "backend": {
    "imageid": "kubernetes-kubeadm-1node"
  },
  "details": {
    "steps": [{ "text": "step1/text.md", "verify": "step1/verify.sh" }],
    "intro": { "text": "intro.md", "courseData": "foreground.sh" }
  }
}
```

The `courseData` in the intro runs `foreground.sh` when the scenario loads.

---

## foreground.sh behaviour

`foreground.sh` does two things:

1. Clones the repo into `/root/cka-bench` (if not present)
2. Runs `tasks/<id>/setup.sh` to inject the broken state

The repo URL defaults to `https://github.com/your-org/cka-bench`.
Override it by setting the `REPO_URL` environment variable in the Killercoda scenario
settings, or by editing the generated `foreground.sh`.

---

## Publishing to Killercoda

1. Push the repository to GitHub (or another public Git host).
2. Update `REPO_URL` in the generated `foreground.sh` files to point to your repo.
3. Log in to [killercoda.com](https://killercoda.com) and create a new scenario.
4. Upload the contents of `adapters/killercoda/scenarios/<task-id>/` as the scenario source.
5. Test the scenario in the Killercoda editor.

---

## Keeping scenarios in sync

Scenarios are generated from the task source. If you change `setup.sh`, `verify.sh`,
or `prompt.md`, regenerate the scenario:

```bash
make scenario TASK=task-01-broken-service
```

The scenario files are derived outputs. The task directory is the source of truth.

---

## Choosing a backend image

The default backend is `kubernetes-kubeadm-1node`. For tasks that require multiple nodes
(e.g., node affinity, DaemonSets), change the `imageid` in the generated `index.json`:

```json
"backend": { "imageid": "kubernetes-kubeadm-2nodes" }
```

Available Killercoda Kubernetes backend images:
- `kubernetes-kubeadm-1node`
- `kubernetes-kubeadm-2nodes`

Check [killercoda.com/creators](https://killercoda.com/creators) for the current list.
