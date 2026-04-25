Generate a new CKA bench task: **$ARGUMENTS**

The argument is a short task description, e.g. "pod with wrong resource limits" or
"missing configmap causes crashloop". If no argument is given, ask the user what
scenario they want to create before proceeding.

## What you will produce

A complete task directory at `tasks/<task-id>/` containing four files:
- `prompt.md` — human-facing instructions
- `setup.sh` — injects the broken state into the cluster
- `verify.sh` — deterministic pass/fail check (no LLM judging)
- `cleanup.sh` — removes all task resources

## Naming convention

Derive the task ID from the description: lowercase, hyphen-separated, prefixed with
the next available number. Check `tasks/` to find the highest existing number.
Example: if tasks go up to `task-05-*`, the new one is `task-06-<slug>`.

## Step-by-step

1. **List existing tasks** — run `ls tasks/` to find the next task number and confirm
   the ID you will use. Tell the user the chosen ID before writing anything.

2. **Design the scenario** — think through:
   - What is the broken Kubernetes object and how is it broken?
   - What does a human need to do to fix it?
   - What is the single, deterministic condition that proves it is fixed?
   - Is this scenario achievable on a single-node kind cluster?
     (See README.md "Environment Limitations" section for what is and is not possible.)

3. **Write `prompt.md`** — use this exact structure:
   ```
   # Task: <Title>

   **Namespace:** `<ns>`
   **Difficulty:** Easy | Medium | Hard
   **Topic:** <topic>

   ## Situation
   <2–3 sentences describing what is broken and the symptom the user sees>

   ## Your Goal
   <1–2 sentences stating exactly what the end state must be>

   ## Hints

   <details>
   <summary>Hint 1</summary>
   <first diagnostic command to run>
   </details>

   <details>
   <summary>Hint 2</summary>
   <second diagnostic step>
   </details>

   <details>
   <summary>Hint 3</summary>
   <the fix, written explicitly enough to be actionable>
   </details>

   ## Verification

   ```powershell
   # Windows
   .\run.ps1 verify -Task <task-id>
   ```
   ```bash
   # Linux / macOS
   make verify TASK=<task-id>
   ```
   ```

4. **Write `setup.sh`** — must follow this template exactly:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
     export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
   fi

   NS="<namespace>"

   echo "[setup] Creating namespace ${NS}..."
   kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

   echo "[setup] <what you are creating>..."
   kubectl apply -f - <<EOF
   <YAML for the broken resource(s)>
   EOF

   echo "[setup] Task <N> ready. <One sentence describing the broken state.>"
   ```
   Rules for setup.sh:
   - Use `--dry-run=client -o yaml | kubectl apply -f -` for namespace (idempotent)
   - Inject a clearly broken state — wrong image, wrong label, missing resource, etc.
   - Do not print the prompt; `prep-env/start.sh` handles that
   - Keep it minimal — only what is needed to establish the broken state

5. **Write `verify.sh`** — must be deterministic and exit 0 on pass, 1 on fail:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
     export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
   fi

   NS="<namespace>"

   # Query the single condition that proves success
   VALUE=$(kubectl get <resource> -n "${NS}" -o jsonpath='<path>' 2>/dev/null || echo "NotFound")

   if [ "${VALUE}" = "<expected>" ]; then
     echo "PASS: <what passed>"
     exit 0
   else
     echo "FAIL: <what failed — include the actual value and what was expected>"
     echo "      <one actionable hint>"
     exit 1
   fi
   ```
   Rules for verify.sh:
   - Check one concrete, observable fact (pod phase, endpoint count, RBAC can-i, etc.)
   - Never call an LLM, never use fuzzy matching
   - FAIL message must tell the user what to look at next

6. **Write `cleanup.sh`** — must follow this template:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
     export PATH="${HOME}/AppData/Local/Microsoft/WinGet/Links:${PATH}"
   fi

   NS="<namespace>"

   # Remove any cluster-scoped resources first (taints, ClusterRoles, etc.)
   # <only if needed>

   echo "[cleanup] Deleting namespace ${NS}..."
   kubectl delete namespace "${NS}" --ignore-not-found
   echo "[cleanup] Done."
   ```
   Rules for cleanup.sh:
   - Namespace deletion removes all namespaced resources automatically
   - Explicitly remove cluster-scoped resources (taints, ClusterRoles, ClusterRoleBindings, PVs) before or after namespace deletion
   - Use `--ignore-not-found` on every delete call

7. **Live test** — after writing all four files:
   a. Run `bash tasks/<task-id>/setup.sh` — confirm it exits cleanly
   b. Run `bash tasks/<task-id>/verify.sh` — confirm it exits 1 (task is broken)
   c. Apply the fix manually using only `kubectl` commands
   d. Run `bash tasks/<task-id>/verify.sh` again — confirm it exits 0 (PASS)
   e. Run `bash tasks/<task-id>/cleanup.sh` — confirm it exits cleanly

8. **Report** — tell the user:
   - The task ID and files created
   - The exact fix a human needs to apply
   - The verify condition that proves success
   - Whether the live test passed

## Hard constraints

- Only create scenarios achievable on a single-node kind cluster — check README.md
  "Environment Limitations" before designing
- setup.sh must be idempotent (safe to run twice)
- verify.sh must never require the user to have applied a specific command — only the
  end state matters
- All four files must be executable (`chmod +x` is handled by bash, but shebang is required)
- Namespace must follow the pattern `cka-task-<NN>`
