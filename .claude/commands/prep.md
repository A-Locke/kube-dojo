Set up the CKA bench task: **$ARGUMENTS**

1. Run `bash adapters/local-kind/create_cluster.sh` to ensure the cluster exists and the kubeconfig is set.
   (This is idempotent — it skips creation if the cluster already exists.)
2. Run `bash tasks/$ARGUMENTS/setup.sh` to inject the broken state.
3. Read and display the task prompt from `tasks/$ARGUMENTS/prompt.md`.
4. Tell me what to do to verify my solution when I am ready.
