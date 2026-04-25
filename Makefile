.PHONY: help check check-install cluster-create cluster-destroy cluster-reset prep verify clean solve solve-local suite suite-local scenario

CLUSTER_NAME ?= cka-bench
TASK         ?=
TIMEOUT      ?= 300

# ── Shell and tool detection ───────────────────────────────────────────────────
# Windows: cluster targets (PS1) work via PWSH. Bash-recipe targets (prep/verify/
# clean/solve-local) are not supported under GnuWin32 make — use .\run.ps1 instead.
# Linux/macOS: all targets work normally.

ifeq ($(OS),Windows_NT)
  PWSH   := $(shell (where pwsh >NUL 2>&1 && echo pwsh) || echo powershell)
  PYTHON := python
else
  PWSH   := pwsh
  PYTHON := $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python)
endif

# ── Help ───────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "CKA Bench - Kubernetes CKA Training Platform"
	@echo ""
	@echo "Setup:"
	@echo "  make check             Check all prerequisites"
	@echo "  make check-install     Check and auto-install missing prerequisites"
	@echo ""
	@echo "Cluster management:"
	@echo "  make cluster-create        Create local kind cluster"
	@echo "  make cluster-destroy       Destroy local kind cluster"
	@echo "  make cluster-reset         Destroy and recreate cluster"
	@echo ""
	@echo "Task workflow:"
	@echo "  make prep    TASK=<id>     Setup task and print prompt (human mode)"
	@echo "  make verify  TASK=<id>     Run deterministic verification"
	@echo "  make clean   TASK=<id>     Cleanup task resources"
	@echo "  make solve       TASK=<id>  Run AI solver (requires ANTHROPIC_API_KEY)"
	@echo "  make solve-local TASK=<id>  Run AI solver via local claude CLI (no API key)"
	@echo ""
	@echo "  In VS Code with Claude Code: type /solve <task-id>"
	@echo ""
	@echo "Harness:"
	@echo "  make suite                 Run all tasks with agent, aggregate results"
	@echo "  make suite TASK='t1 t2'    Run specific tasks"
	@echo ""
	@echo "Killercoda:"
	@echo "  make scenario TASK=<id>    Generate Killercoda scenario files"
	@echo "  make scenario TASK=all     Generate all Killercoda scenarios"
	@echo ""
	@echo "Available tasks:"
	@$(PYTHON) -c "import os; [print(' ', t) for t in sorted(os.listdir('tasks')) if os.path.isdir(os.path.join('tasks', t))]"
	@echo ""

# ── Prerequisite check ────────────────────────────────────────────────────────

check:
	@$(PWSH) -ExecutionPolicy Bypass -File scripts/check_prerequisites.ps1

check-install:
	@$(PWSH) -ExecutionPolicy Bypass -File scripts/check_prerequisites.ps1 -Install

# ── Cluster management (PowerShell scripts — work on Windows without WSL) ────

cluster-create:
ifeq ($(OS),Windows_NT)
	@$(PWSH) -ExecutionPolicy Bypass -File adapters/local-kind/create_cluster.ps1
else
	@bash adapters/local-kind/create_cluster.sh
endif

cluster-destroy:
ifeq ($(OS),Windows_NT)
	@$(PWSH) -ExecutionPolicy Bypass -File adapters/local-kind/destroy_cluster.ps1
else
	@bash adapters/local-kind/destroy_cluster.sh
endif

cluster-reset:
ifeq ($(OS),Windows_NT)
	@$(PWSH) -ExecutionPolicy Bypass -File adapters/local-kind/reset_cluster.ps1
else
	@bash adapters/local-kind/reset_cluster.sh
endif

# ── Task workflow ─────────────────────────────────────────────────────────────
# On Windows these targets require Git Bash on PATH. Use .\run.ps1 instead.

ifeq ($(OS),Windows_NT)
prep verify clean solve solve-local suite scenario:
	@echo "ERROR: On Windows use .\\run.ps1 instead of make for task commands."
	@echo "       Example: .\\run.ps1 $@ -Task $(TASK)"
	@exit 1
else

prep:
	@[ -n "$(TASK)" ] || (echo "ERROR: TASK is required. Usage: make prep TASK=<task-id>"; exit 1)
	@bash prep-env/start.sh $(TASK)

verify:
	@[ -n "$(TASK)" ] || (echo "ERROR: TASK is required. Usage: make verify TASK=<task-id>"; exit 1)
	@bash tasks/$(TASK)/verify.sh

clean:
	@[ -n "$(TASK)" ] || (echo "ERROR: TASK is required. Usage: make clean TASK=<task-id>"; exit 1)
	@bash tasks/$(TASK)/cleanup.sh

solve:
	@[ -n "$(TASK)" ] || (echo "ERROR: TASK is required. Usage: make solve TASK=<task-id>"; exit 1)
	@$(PYTHON) harness/run_task.py --task $(TASK) --mode agent --timeout $(TIMEOUT)

solve-local:
	@[ -n "$(TASK)" ] || (echo "ERROR: TASK is required. Usage: make solve-local TASK=<task-id>"; exit 1)
	@bash solver-agent/agent_local.sh $(TASK)

suite-local:
	@if [ -n "$(TASK)" ]; then \
		$(PYTHON) harness/run_suite.py --tasks $(TASK) --mode local --timeout $(TIMEOUT); \
	else \
		$(PYTHON) harness/run_suite.py --mode local --timeout $(TIMEOUT); \
	fi

suite:
	@if [ -n "$(TASK)" ]; then \
		$(PYTHON) harness/run_suite.py --tasks $(TASK) --mode agent --timeout $(TIMEOUT); \
	else \
		$(PYTHON) harness/run_suite.py --mode agent --timeout $(TIMEOUT); \
	fi

scenario:
	@[ -n "$(TASK)" ] || (echo "ERROR: TASK is required. Usage: make scenario TASK=<task-id|all>"; exit 1)
	@$(PYTHON) adapters/killercoda/generate_scenario.py $(TASK)

endif
