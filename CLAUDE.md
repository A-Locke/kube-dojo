# Claude.md

## Role
You are an execution-focused AI engineering agent responsible for building a reproducible Kubernetes-based benchmarking and training environment for CKA-style tasks.

You are building a repository that must support:
1. Local Docker-based execution using `kind`
2. Killercoda-compatible scenario execution
3. Human exam-prep mode
4. Agentic solver mode

Your job is to build the system, scripts, docs, and agent instructions needed to make all of these work from one coherent repo.

---

## Core Operating Principle

There must be **one canonical task definition** and **multiple backend adapters**.

A task is **not** responsible for creating a cluster.

A task is responsible for:
- assuming a Kubernetes cluster already exists
- injecting a broken or incomplete CKA-style state into that cluster
- presenting a prompt to the user or agent
- verifying whether the final state is correct
- cleaning up task-specific resources

This principle is mandatory.

### What varies by backend
Only the backend lifecycle and presentation wrapper should vary.

#### Local backend
- the repo creates and destroys a local `kind` cluster
- the repo sets kubeconfig and context
- the repo then runs shared task setup against that cluster

#### Killercoda backend
- Killercoda provides the Kubernetes backend image and prebuilt environment
- the scenario wrapper then runs the same shared task setup against that already-available cluster

Therefore:
- local `kind` does **not** emulate Killercoda directly
- Killercoda does **not** replace shared task logic
- both backends apply the **same scenario state** using the **same task contract**

---

## Core Objectives
- Build a fully working repository end-to-end
- Ensure the project runs locally using Docker and `kind`
- Ensure the project can also be packaged as Killercoda-compatible scenarios
- Use real Kubernetes clusters and real `kubectl` interactions
- Prioritize determinism, reproducibility, and debuggability
- Support both a human exam taker and an autonomous agent solver

---

## Hard Constraints
- MUST use `kind` for local Kubernetes clusters
- MUST run locally in a Docker-compatible environment
- MUST be compatible with Killercoda scenario structure
- MUST NOT depend on browser automation
- MUST use real `kubectl` interactions
- MUST implement deterministic verification; no LLM judging
- MUST support full reset between runs
- MUST log all agent actions and outputs
- MUST keep tasks isolated and reproducible

---

## Killercoda Compatibility Requirements
The repository must be intentionally designed so tasks can be used in Killercoda scenarios.

Killercoda scenarios are structured around:
- an `index.json` scenario definition
- markdown content files
- optional `foreground.sh` and `background.sh`
- optional per-step `verify.sh`
- a selected backend image such as `ubuntu`, `kubernetes-kubeadm-1node`, or `kubernetes-kubeadm-2nodes`

Because of this, you MUST separate:
1. backend/cluster provisioning
2. task setup and task verification
3. human instructions / scenario text
4. agent execution logic

Do NOT tightly couple task logic to local-only cluster creation scripts.

Local `kind` cluster creation and Killercoda backend selection are different concerns and must remain separate.

---

## Required Architectural Split

Design the repo so that tasks are portable across two execution backends.

### Backend A: Local
- Local Docker
- `kind` cluster creation managed by repo scripts

Required local-only responsibilities:
- create cluster
- destroy cluster
- reset cluster
- export or merge kubeconfig
- optionally select or confirm context

### Backend B: Killercoda
- Killercoda-selected backend image
- No assumption that the repo itself creates the cluster inside Killercoda
- Task setup must be able to run after the backend is already present

Required Killercoda-only responsibilities:
- select correct backend image
- generate `index.json`
- generate scenario step markdown
- optionally generate `foreground.sh`, `background.sh`, and `verify.sh`
- present human-readable instructions in scenario steps

### Shared task layer
The shared task layer must be backend-agnostic.

Shared task scripts must:
- assume a Kubernetes cluster is already available
- use the current kubeconfig / kubectl context
- create the intended broken state
- avoid backend-specific assumptions unless explicitly parameterized

Shared task scripts must NOT:
- create a `kind` cluster
- call Killercoda APIs
- assume browser-only UI
- hardcode local-only filesystem paths unless parameterized

---

## Product Modes
The repo must support two primary modes:

### Mode A: Human CKA Prep
A human starts the environment, loads a broken task, reads instructions, configures kubectl access if needed, and solves the task manually.

### Mode B: Agentic Solver
A separate AI solver reads the task prompt, inspects the cluster, executes commands, and attempts to solve the same task automatically.

Both modes must rely on the same underlying task definitions and verification logic.

---

## Shared Task Contract

Use a shared task format across all systems.

Each task must be source-of-truth portable and contain:
- prompt/instructions
- task setup logic
- deterministic verification logic
- cleanup/reset logic
- metadata

For local mode, the task may be wrapped by CLI helpers.
For Killercoda mode, the task may be wrapped by scenario files like `index.json`, step markdown, and optional foreground/background scripts.

The task definition should be designed so a generator can emit:
- local task assets
- Killercoda scenario assets

### Example execution flow

#### Local flow
1. local adapter creates `kind` cluster
2. local adapter configures kubeconfig/context
3. local adapter invokes `tasks/<task_id>/setup.sh`
4. human or solver uses `prompt.md`
5. `verify.sh` checks success
6. `cleanup.sh` removes task-specific state

#### Killercoda flow
1. Killercoda scenario selects backend image
2. Kubernetes environment becomes available
3. scenario wrapper invokes `tasks/<task_id>/setup.sh` or generated equivalent
4. human uses scenario markdown / prompt
5. `verify.sh` checks success
6. `cleanup.sh` or scenario teardown removes task-specific state

The shared task behavior must be the same in both flows.

---

## Human Experience Requirements
The repo must support a human-friendly experience, not only raw scripts.

The implementation must include:
- a strong root `README.md`
- clear step-by-step local setup instructions
- clear task launch instructions
- explicit kubeconfig handling instructions
- a guided launcher flow or menu for humans

For Killercoda-compatible output, the human path must also include scenario-friendly markdown content that can be shown in-browser.

---

## Agent Constraints
The solver agent must behave like a CLI-based human exam taker.

Allowed tools:
- `kubectl`
- `bash`
- `jq`
- basic file I/O

Do not rely on:
- hidden cluster admin shortcuts
- direct Kubernetes API clients that bypass the normal CLI workflow
- browser control
- non-deterministic grading

---

## Implementation Constraints
- Prefer deterministic, hand-authored tasks first
- Do not start with AI-generated task creation
- Keep dependencies minimal
- Keep shell scripts readable and robust
- Keep Python code simple and modular
- All important flows must be runnable via CLI
- Local and Killercoda workflows must share as much task logic as practical

---

## Required Repo-Level Outputs
You must produce:
- a fully working repo
- local `kind` cluster lifecycle scripts
- a shared task system
- at least 5 initial tasks
- a working prep environment
- a working solver agent loop
- a local execution harness
- Killercoda-compatible scenario generation or layout
- documentation for both local and Killercoda usage
- agent instruction files as needed for execution sub-agents

---

## Documentation Requirements
The root `README.md` is a required deliverable.

It must explain:
- what the project does
- the difference between local mode and Killercoda mode
- the difference between backend provisioning and task setup
- prerequisites
- local cluster creation
- task preparation
- kubeconfig handling
- human solving flow
- agent solving flow
- verification
- reset and cleanup
- how Killercoda compatibility is structured

You should also create additional docs where useful, such as:
- `docs/architecture.md`
- `docs/task-authoring.md`
- `docs/killercoda.md`
- `docs/solver-agent.md`

---

## Quality Bar
Favor:
- portability
- clarity
- deterministic behavior
- debuggability
- operator understanding

Avoid:
- hidden magic
- local-only assumptions inside task logic
- fragile scripts
- coupling scenario instructions to backend provisioning
- architecture that makes Killercoda an afterthought

---

## First Milestone
The first meaningful milestone should prove all of the following:
1. create a local `kind` cluster
2. prepare one broken task on that cluster
3. guide a human to solve it manually
4. verify the result deterministically
5. run the agent against the same task
6. represent the same task in a Killercoda-compatible structure
7. preserve the split between backend provisioning and task setup

---

## Notes to the Execution Agent
When choosing between elegance and usability:
- prefer usability

When choosing between abstraction and portability:
- prefer portability

When choosing between clever generation and trustworthy task behavior:
- prefer trustworthy task behavior

The repository must feel like a serious CKA training and benchmarking platform, not a loose collection of scripts.
