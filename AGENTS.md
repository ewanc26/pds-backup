# AGENTS.md

Guidance for AI coding agents working in **pds-backup**.

## Project overview

my ATProto PDS backup script.

- Language: Shell
- Default branch: main

## Working rules

- Inspect the README, manifests, CI workflows, and nearby code before editing.
- Preserve existing architecture, naming, formatting, and error-handling conventions.
- Use project scripts for validation; never claim checks you did not run.
- Keep changes scoped and update tests or documentation when behavior changes.
- Use feature branches and pull requests.
- Treat generated files, credentials, deployment configuration, and release metadata as sensitive.

## Recent history

Remove the local archive after an unchanged backup run; test: cover the unchanged-backup restart failure; Abort backup when PDS stop or restart fails (#4); Merge branch 'main' of github.com:ewanc26/pds-backup; docs: tailor contributor and agent guidance (#1); chore: clean up linguist and gitignore rules; Symlink droid/opencode/qwen/rovodev skill dirs to .agents/skills