# Architecture

## Core principle

There is one source of truth: **the task definition**.

Everything else — cluster creation, scenario packaging, agent orchestration — is an adapter around that task.

A task:
- **assumes** a Kubernetes cluster already exists
- **injects** a broken or incomplete cluster state
- **presents** a prompt
- **verifies** the result deterministically
- **cleans up** its own resources

A task does **not** create a cluster. A task does not know or care whether it runs locally or on Killercoda.

---

## Directory layout

```
.
├── tasks/                          shared task layer (backend-agnostic)
│   └── task-01-broken-service/
│       ├── prompt.md               task description
│       ├── setup.sh                inject broken state
│       ├── verify.sh               deterministic pass/fail
│       ├── cleanup.sh              remove task resources
│       └── metadata.yaml           id, title, difficulty, topic
│
├── adapters/
│   ├── local-kind/                 Backend A: local Docker + kind
│   │   ├── kind-config.yaml        cluster spec (1 control-plane, 1 worker)
│   │   ├── create_cluster.sh
│   │   ├── destroy_cluster.sh
│   │   └── reset_cluster.sh
│   │
│   └── killercoda/                 Backend B: Killercoda
│       ├── generate_scenario.py    generates scenario files from a task dir
│       └── scenarios/              generated output (gitignored or committed)
│
├── harness/
│   ├── run_task.py                 setup → solve → verify → log (single task)
│   └── run_suite.py                run many tasks, aggregate results
│
├── solver-agent/
│   └── agent.py                    Claude-powered ReAct agent
│
├── prep-env/
│   ├── start.sh                    ensure cluster + setup task + print prompt
│   └── stop.sh                     destroy cluster
│
├── logs/                           per-run JSON logs
├── Makefile
├── requirements.txt
└── README.md
```

---

## Execution flows

### Local (human mode)

```
make cluster-create
  └─ adapters/local-kind/create_cluster.sh
       └─ kind create cluster

make prep TASK=<id>
  └─ prep-env/start.sh
       ├─ ensures kind cluster exists
       ├─ kubectl config use-context kind-cka-bench
       └─ tasks/<id>/setup.sh          ← shared task layer

(human solves manually)

make verify TASK=<id>
  └─ tasks/<id>/verify.sh              ← shared task layer
```

### Local (agent mode)

```
make solve TASK=<id>
  └─ harness/run_task.py --mode agent
       ├─ tasks/<id>/setup.sh
       ├─ solver-agent/agent.py        ← Claude + kubectl tool loop
       └─ tasks/<id>/verify.sh
```

### Killercoda

```
(Killercoda provides kubernetes-kubeadm-1node backend)

foreground.sh
  └─ git clone <repo>
  └─ tasks/<id>/setup.sh              ← same shared task layer

(human reads step1/text.md = prompt.md)

step1/verify.sh
  └─ tasks/<id>/verify.sh             ← same shared task layer
```

---

## Design decisions

### Why not generate tasks with AI?
Determinism. Hand-authored tasks produce known broken states and known correct fixes.
AI-generated tasks are harder to verify and may be ambiguous.

### Why is verify.sh a shell script rather than a Python test?
Portability. Shell scripts run identically on a local cluster and inside a Killercoda container.
They have no Python dependency chain to manage.

### Why does kind-config.yaml include a worker node?
CKA tasks often involve node-level concerns (taints, node affinity, DaemonSets).
A separate worker node makes those tasks realistic without tainting the control-plane.

### Why does the harness log to JSON?
The JSON logs are structured and machine-readable. They make it straightforward to
build a results dashboard, compare agent runs over time, or run regression checks.
