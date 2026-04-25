# Solver Agent

## Overview

The solver agent (`solver-agent/agent.py`) is an autonomous Kubernetes troubleshooter.
It reads a task prompt, inspects the cluster with kubectl, applies fixes, and verifies
the result — behaving like a human CKA candidate at a terminal.

---

## How it works

The agent uses a [ReAct](https://arxiv.org/abs/2210.03629)-style loop powered by
Claude's tool-use API:

```
Read prompt
  ↓
Loop:
  Claude reasons about what to do
  → calls kubectl / bash tool
  ← gets command output
  Claude interprets output
  → applies fix
  ← observes result
  ...until DONE or timeout
  ↓
Run verify.sh → exit 0 or 1
```

---

## Tools available to the agent

| Tool | What it does |
|---|---|
| `kubectl` | Runs a kubectl subcommand. Input: everything after `kubectl`. |
| `bash` | Runs a shell command. Useful for pipes, jq, grep. |

The agent cannot use the Kubernetes API directly, call external services,
or take admin shortcuts outside of normal kubectl workflows.

---

## Running the agent

Via make:
```bash
make solve TASK=task-01-broken-service
```

Direct:
```bash
python3 harness/run_task.py --task task-01-broken-service --mode agent
```

The harness runs `setup.sh` first, then launches the agent, then runs `verify.sh`.

---

## Configuration

| Variable / flag | Default | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | (required) | Your Anthropic API key |
| `--model` | `claude-opus-4-7` | Claude model to use |
| `--timeout` | `300` | Max seconds before agent is stopped |

---

## Logs

Every run produces a JSON log in `logs/`:

```json
{
  "task": "task-01-broken-service",
  "mode": "agent",
  "start_time": 1713600000.0,
  "result": "PASS",
  "elapsed": 42.3
}
```

Run the full suite and view aggregate results:

```bash
make suite
cat logs/suite_<timestamp>.json
```

---

## Agent behaviour expectations

The agent is designed to mirror a methodical exam taker:

1. **Inspect before fixing** — always runs `kubectl get` / `kubectl describe` first
2. **Targeted fixes** — patches or edits specific resources rather than deleting and recreating everything
3. **Self-verification** — re-checks the resource state after each fix attempt
4. **Stops on DONE** — declares completion explicitly before the harness runs `verify.sh`

---

## Extending the agent

To add new tools (e.g., `helm`, `jq` as a first-class tool), add an entry to the
`TOOLS` list in `solver-agent/agent.py` and handle it in `execute_tool()`.

To change the system prompt or agent persona, edit `SYSTEM_PROMPT` in `agent.py`.
