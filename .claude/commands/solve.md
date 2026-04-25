Solve the CKA bench task: **$ARGUMENTS**

Think out loud at every step. Before each command, say what you are about to run and why.
After each command, say what the output tells you. This is a learning environment — the
explanation is as important as the fix.

## Steps

1. Read the task prompt at `tasks/$ARGUMENTS/prompt.md`
2. **Explain** what the task is asking in your own words.
3. Check whether the task namespace exists (look for the namespace in `metadata.yaml`). If the broken state is not yet set up, run `bash tasks/$ARGUMENTS/setup.sh` first. Explain what setup does.
4. **Inspect** the cluster — run `kubectl get`, `kubectl describe`, and `kubectl get events`. Before each command, state what you expect to learn from it. After each result, state what you now know.
5. **Diagnose** — explain the root cause in plain terms before touching anything.
6. **Fix** — describe the change you are about to make and why it addresses the root cause, then apply it.
7. Run `bash tasks/$ARGUMENTS/verify.sh`. Explain what the check is testing.
8. If verification fails, explain why the fix did not work, then repeat from step 4.
9. When verification passes, give a final summary:
   - What was broken and why
   - What you changed to fix it
   - What the verify step confirmed

## Rules

- Use only `kubectl` and `bash` — no direct API calls, no shortcuts.
- Never run a command without first explaining what you expect it to show.
- Never apply a fix without first explaining what it does and why.
- After each fix attempt, re-run `verify.sh` before claiming success.
