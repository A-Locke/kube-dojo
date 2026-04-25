# kube-dojo

A Kubernetes CKA-style training and benchmarking platform.

- Practice CKA exam tasks on a real local Kubernetes cluster
- Run an AI solver agent against the same tasks
- Export any task as a Killercoda browser-based scenario

---

## What This Is

**kube-dojo** gives you reproducible Kubernetes troubleshooting tasks with deterministic verification.
Each task injects a broken state into a cluster and asks you (or an AI agent) to fix it.

The same task definitions work across two backends:

| Backend | Cluster | Task logic |
|---|---|---|
| **Local (kind)** | Created by this repo via `kind` | Shared `setup.sh / verify.sh` |
| **Killercoda** | Provided by Killercoda's browser environment | Same shared scripts |

**The cluster and the task are always separate concerns.**

---

## Architecture

```
tasks/                      ← shared task definitions (backend-agnostic)
  task-01-broken-service/
    prompt.md               ← task description shown to human or agent
    setup.sh                ← injects broken state (assumes cluster exists)
    verify.sh               ← deterministic pass/fail check
    cleanup.sh              ← removes task resources
    metadata.yaml           ← id, title, difficulty, topic

adapters/
  local-kind/               ← creates/destroys kind cluster (PS1 + bash)
  killercoda/               ← generates Killercoda scenario files

harness/
  run_task.py               ← setup → solve → verify → log
  run_suite.py              ← run multiple tasks and aggregate results

solver-agent/
  agent.py                  ← AI solver using Claude + kubectl (API mode)
  agent_local.sh            ← AI solver using local claude CLI (no API key)

prep-env/
  start.sh                  ← ensure cluster + setup task + print prompt
  stop.sh                   ← destroy cluster

run.ps1                     ← Windows task runner (replaces make on Windows)
Makefile                    ← task runner for Linux / macOS / CI
```

See [docs/architecture.md](docs/architecture.md) for a detailed breakdown.

---

## Prerequisites

| Tool | Purpose | Required |
|---|---|---|
| Docker Desktop | Required by kind | Yes |
| [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) | Local Kubernetes clusters | Yes |
| kubectl | Kubernetes CLI | Yes |
| Python 3.9+ | Harness and solver agent | Yes |
| Git for Windows | Provides Git Bash for task scripts | Yes (Windows) |
| make | Convenience wrapper | Linux/macOS only |
| claude CLI | Local agent solver (no API key) | Optional |
| ANTHROPIC_API_KEY | API-based solver and suite runner | Optional |

### Check and install prerequisites

```powershell
# Check what is missing
.\scripts\check_prerequisites.ps1

# Check and auto-install missing tools
.\scripts\check_prerequisites.ps1 -Install
```

Install Python packages manually if needed:

```powershell
pip install -r requirements.txt
```

---

## Quick Start — Windows (PowerShell)

All commands use `run.ps1`, the native PowerShell task runner.
No `make` or shell switching required.

### Step 1 — Check prerequisites

```powershell
.\scripts\check_prerequisites.ps1
```

All items should show `[OK]`. Git for Windows and Docker Desktop are the two most
commonly missing tools. Install them first if needed.

### Step 2 — Create the cluster

```powershell
.\run.ps1 cluster-create
```

This creates a single-node `kind` cluster named `cka-bench` (the internal cluster identifier used throughout the scripts) and sets your kubectl context to `kind-cka-bench`.

Wait a few seconds, then verify:

```powershell
kubectl get nodes
# NAME                      STATUS   ROLES           AGE   VERSION
# cka-bench-control-plane   Ready    control-plane   ...
```

### Step 3 — Start a task

```powershell
.\run.ps1 prep -Task task-01-broken-service
```

This runs `setup.sh` to inject a broken Kubernetes state into the cluster,
then prints the task prompt describing what is broken and what you need to fix.

### Step 4 — Solve the task

Read the prompt. Use `kubectl` to diagnose and fix the issue.

Useful commands:

```powershell
kubectl get all -n <namespace>
kubectl describe <resource> <name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Step 5 — Verify your solution

```powershell
.\run.ps1 verify -Task task-01-broken-service
```

Exits `0` (PASS) or `1` (FAIL) with a descriptive message.

### Step 6 — Clean up

```powershell
.\run.ps1 clean -Task task-01-broken-service
```

Removes all task-specific resources from the cluster. The cluster itself stays running.

---

## Quick Start — Linux / macOS

```bash
# Check prerequisites
./scripts/check_prerequisites.sh   # or: make check

# Create cluster
make cluster-create

# Verify kubectl
kubectl get nodes

# Run a task
make prep TASK=task-01-broken-service

# Verify solution
make verify TASK=task-01-broken-service

# Clean up
make clean TASK=task-01-broken-service
```

---

## Agent Solver

There are two solver backends. Use whichever fits your setup.

### Option A — VS Code / Claude Code (no API key required)

If you have this folder open in VS Code with the Claude Code extension,
type in the chat:

```
/prep task-01-broken-service
```

or to go straight to solving:

```
/solve task-01-broken-service
```

Claude Code acts as the agent directly — it has `kubectl` access via the
Bash tool and uses your existing Claude Code authentication.

### Option B — Local claude CLI (no API key required)

```powershell
# Windows
.\run.ps1 solve-local -Task task-01-broken-service

# Linux/macOS
make solve-local TASK=task-01-broken-service
```

The agent thinks out loud at every step — it explains before each command
and interprets output after. Good for learning.

### Option C — Anthropic API (scripted / CI)

Requires `ANTHROPIC_API_KEY`.

```powershell
# Set the key
$env:ANTHROPIC_API_KEY = "sk-ant-..."

# Windows
.\run.ps1 solve -Task task-01-broken-service

# Linux/macOS
make solve TASK=task-01-broken-service
```

Run the full suite against all tasks (no API key required):

```powershell
# Windows
.\run.ps1 suite-local

# Linux/macOS
make suite-local
```

Or with the Anthropic API:

```powershell
# Windows
.\run.ps1 suite

# Linux/macOS
make suite
```

All 5 tasks pass end-to-end with the local solver:

```
  [PASS] task-01-broken-service        (60s)
  [PASS] task-02-deployment-not-ready  (221s)
  [PASS] task-03-rbac-issue            (50s)
  [PASS] task-04-pvc-binding           (71s)
  [PASS] task-05-scheduling-issue      (120s)

  5/5 tasks passed
```

---

## Environment Limitations

This repo runs Kubernetes inside a single-node [kind](https://kind.sigs.k8s.io/) cluster on Docker Desktop. That covers the majority of CKA exam topics, but a few require infrastructure that kind cannot replicate.

### What works fully

| CKA Topic | Notes |
|---|---|
| Workloads — Deployments, StatefulSets, DaemonSets, Jobs | Full support |
| Scheduling — taints, tolerations, affinity, node selectors, priority | Full support |
| RBAC — Roles, ClusterRoles, ServiceAccounts | Full support |
| ConfigMaps, Secrets | Full support (note: tmpfs noswap warning is cosmetic) |
| Services — ClusterIP, NodePort, ExternalName | Full support |
| PVCs and StorageClasses | Single StorageClass (`standard`, local-path-provisioner) |
| Resource limits, LimitRanges, ResourceQuotas | Full support |
| Pod disruption budgets, HPA | Full support |
| Ingress (with controller installed) | Full support |
| CoreDNS troubleshooting | Full support |
| Static pods | Full support via `/etc/kubernetes/manifests` inside the node |
| Liveness / readiness / startup probes | Full support |

### What is limited or not possible

| CKA Topic | Limitation |
|---|---|
| **NetworkPolicy enforcement** | The default CNI (kindnet) does **not** enforce NetworkPolicy rules. Policies can be created and `kubectl get networkpolicy` works, but traffic is never actually blocked. To test real enforcement you would need to swap kindnet for Calico or Cilium — not done by default here. |
| **LoadBalancer Services** | No cloud provider and no MetalLB installed, so `EXTERNAL-IP` stays `<pending>` indefinitely. NodePort and ClusterIP tasks work fine. |
| **etcd backup and restore** | etcd runs as a static pod, not a systemd service. `etcdctl snapshot save/restore` commands work, but the procedure differs from a kubeadm-on-VM cluster: there is no `etcd.service` to stop/start and data lives inside a Docker volume. The skill is practised but the exact exam workflow (stopping the service, moving the data dir) does not map 1:1. |
| **Cluster upgrade with kubeadm** | kind nodes come pre-built with a fixed Kubernetes version. `kubeadm upgrade` cannot be run inside the node because the node image is not set up for that workflow. Upgrade tasks are not feasible here. |
| **Multi-node failure simulation** | The default config is a single control-plane node with no workers. Tasks that require draining a worker, simulating a node failure, or testing pod rescheduling across nodes need the kind config extended with worker nodes (`role: worker` entries in `kind-config.yaml`). |
| **SSH into nodes** | Nodes are Docker containers. You can reach them with `docker exec -it cka-bench-control-plane bash`, but there is no `ssh` or standard node IP accessible from outside Docker. Tasks that require `ssh node01` do not apply directly. |
| **Cloud provider storage (EBS, GCE PD, Azure Disk)** | Not available. Only `standard` (local-path) StorageClass exists. Tasks involving specific StorageClass provisioners should use `standard` as a stand-in. |

---

## Available Tasks

| Task | Title | Difficulty | Topic |
|---|---|---|---|
| `task-01-broken-service` | Fix Broken Service Routing | Easy | Services, Selectors |
| `task-02-deployment-not-ready` | Fix Deployment With Bad Image | Easy | Deployments |
| `task-03-rbac-issue` | Fix RBAC — Missing Permissions | Medium | RBAC |
| `task-04-pvc-binding` | Fix PVC Stuck in Pending | Medium | Storage |
| `task-05-scheduling-issue` | Fix Pod Scheduling — Taint/Toleration | Medium | Scheduling |

---

## Kubeconfig

After `cluster-create`, kind exports the kubeconfig to `~/.kube/config`
and sets the context to `kind-cka-bench`.

Verify the active context:

```powershell
kubectl config current-context
# kind-cka-bench
```

To switch back to another context:

```powershell
kubectl config use-context <other-context>
```

---

## Killercoda Compatibility

Tasks can be published as interactive browser-based scenarios on [killercoda.com](https://killercoda.com).
Killercoda provides the Kubernetes cluster — your repo provides the scenario definition, setup script, and verify script.

### How it works

When a user starts a Killercoda scenario, the platform:
1. Spins up a pre-built Kubernetes node (no kind, no Docker Desktop required)
2. Runs `foreground.sh` — which clones **kube-dojo** and calls `tasks/<id>/setup.sh`
3. Shows the task markdown to the user
4. Runs `step1/verify.sh` when the user clicks "Check" — which delegates to `tasks/<id>/verify.sh`

The task logic (setup, verify, cleanup) is identical to local mode. Only the cluster provisioning differs.

### Two-repo setup

Killercoda's creator UI only accepts `owner/repository` — it cannot point at a subdirectory.
Because of this, scenario files must live at the **root** of their own dedicated repository.

| Repo | Purpose |
|---|---|
| `kube-dojo` | Main repo — task scripts, harness, solver, docs |
| `kube-dojo-scenarios` | Scenarios repo — generated Killercoda files only, with each scenario at the root |

`foreground.sh` inside each scenario always clones from `kube-dojo` to get the task scripts. The scenarios repo is just a delivery vehicle for Killercoda.

### Step 1 — Create both repos on GitHub (public)

- `<your-org>/kube-dojo` — this repo
- `<your-org>/kube-dojo-scenarios` — a new empty repo

### Step 2 — Configure `.env`

Copy `.env.example` to `.env` (gitignored) and fill in both values:

```bash
cp .env.example .env
```

```env
KUBE_DOJO_REPO_URL=https://github.com/<your-org>/kube-dojo
KILLERCODA_SCENARIOS_DIR=/path/to/local/checkout/of/kube-dojo-scenarios
```

`KUBE_DOJO_REPO_URL` is baked into each `foreground.sh` so Killercoda knows where to clone task scripts from.
`KILLERCODA_SCENARIOS_DIR` tells the generator where to write the output files.

### Step 3 — Generate and push scenario files

```powershell
# Windows
.\run.ps1 scenario -Task all

# Linux/macOS
make scenario TASK=all
```

The generator writes each scenario directory directly into your `kube-dojo-scenarios` checkout. Each directory contains:

```
task-01-broken-service/
  index.json        # scenario metadata, backend image, step definitions
  intro.md          # shown before step 1
  foreground.sh     # clones kube-dojo and runs setup.sh
  step1/text.md     # the task prompt
  step1/verify.sh   # delegates to tasks/<id>/verify.sh
  finish.md         # shown on completion
```

Then commit and push the scenarios repo:

```bash
cd /path/to/kube-dojo-scenarios
git add .
git commit -m "generate scenarios"
git push
```

### Step 4 — Create scenarios on Killercoda

1. Sign in at [killercoda.com](https://killercoda.com) and go to **Creator**
2. Click **New Scenario**
3. Enter the **repo** as `<your-org>/kube-dojo-scenarios` and the **branch** as `main`
4. Add the deploy key and webhook as instructed by the UI
5. Killercoda discovers `index.json` in each top-level subdirectory — one scenario per task
6. Click **Save** and then **Try** to test it live

### Backend image

All generated scenarios use `kubernetes-kubeadm-1node` — a single-node Kubernetes cluster. This is set in `index.json`:

```json
"backend": { "imageid": "kubernetes-kubeadm-1node" }
```

### Keeping scenarios up to date

After editing task files, regenerate and push the scenarios repo:

```powershell
.\run.ps1 scenario -Task all
```

```bash
cd /path/to/kube-dojo-scenarios
git add .
git commit -m "regenerate scenarios"
git push
```

Killercoda re-fetches from the scenarios repo each time a user starts a scenario.

---

## Known Warnings

### `tmpfs noswap option is not supported`

You may see this warning on the `cka-bench-control-plane` node in Lens or `kubectl get events`:

```
The tmpfs noswap option is not supported. Memory-backed volumes (e.g. secrets,
emptyDirs, etc.) might be swapped to disk.
```

This is a permanent, cosmetic limitation of running Kubernetes inside Docker on Windows. The host kernel does not expose the `noswap` mount option to containers. It has no functional impact on any task in this repo — secrets and emptyDirs work correctly. You can safely ignore it.

### Transient warnings after cluster creation

Right after `cluster-create` or `cluster-reset`, Lens and `kubectl get events` will show a burst of warnings (`node.kubernetes.io/not-ready`, `MountVolume.SetUp failed`, `Node is not ready`). These are normal bootstrap noise from the ~30 second window while the control plane is coming up. They resolve on their own and leave the cluster fully healthy.

---

## Reset and Cleanup

Reset a single task (remove resources, re-inject broken state):

```powershell
.\run.ps1 clean -Task <task-id>
.\run.ps1 prep  -Task <task-id>
```

Destroy the cluster without recreating it:

```powershell
.\run.ps1 cluster-destroy
```

Destroy and recreate the entire cluster:

```powershell
.\run.ps1 cluster-reset
```

---

## Command Reference

### Windows (`run.ps1`)

| Command | Description |
|---|---|
| `.\run.ps1 help` | Show all commands |
| `.\run.ps1 check` | Check prerequisites |
| `.\run.ps1 check-install` | Check and auto-install |
| `.\run.ps1 cluster-create` | Create kind cluster |
| `.\run.ps1 cluster-destroy` | Destroy kind cluster |
| `.\run.ps1 cluster-reset` | Destroy + recreate |
| `.\run.ps1 prep -Task <id>` | Inject broken state, print prompt |
| `.\run.ps1 verify -Task <id>` | Verify solution |
| `.\run.ps1 clean -Task <id>` | Remove task resources |
| `.\run.ps1 solve-local -Task <id>` | AI agent via local claude CLI (no API key) |
| `.\run.ps1 solve -Task <id>` | AI agent via Anthropic API |
| `.\run.ps1 suite-local` | Run all tasks via local claude CLI (no API key) |
| `.\run.ps1 suite` | Run all tasks via Anthropic API |
| `.\run.ps1 scenario -Task <id\|all>` | Generate Killercoda scenario |

### Linux / macOS (`make`)

| Command | Description |
|---|---|
| `make cluster-create` | Create kind cluster |
| `make cluster-destroy` | Destroy kind cluster |
| `make cluster-reset` | Destroy + recreate |
| `make prep TASK=<id>` | Inject broken state, print prompt |
| `make verify TASK=<id>` | Verify solution |
| `make clean TASK=<id>` | Remove task resources |
| `make solve-local TASK=<id>` | AI agent via local claude CLI (no API key) |
| `make solve TASK=<id>` | AI agent via Anthropic API |
| `make suite-local` | Run all tasks via local claude CLI (no API key) |
| `make suite` | Run all tasks via Anthropic API |
| `make scenario TASK=<id\|all>` | Generate Killercoda scenario |

---

## Further Reading

- [docs/architecture.md](docs/architecture.md) — repo structure and design decisions
- [docs/task-authoring.md](docs/task-authoring.md) — how to write new tasks
- [docs/killercoda.md](docs/killercoda.md) — deploying scenarios to Killercoda
- [docs/solver-agent.md](docs/solver-agent.md) — how the AI solver works
