---
name: git-push
description: Push the current branch to remote. Creates a feature branch from main first if currently on main/master.
argument-hint: "<branch name (optional)>"
disable-model-invocation: true
---

# Git Push

Push the current branch to the remote. If on main/master, create a feature branch first.

## Workflow

1. Check current branch:
   ```bash
   git branch --show-current
   ```
2. If on `main` or `master`:
   - Stash uncommitted changes if any: `git stash`
   - Pull latest: `git pull`
   - Detect ticket ID from recent commit message or ask user
   - Create feature branch: `git checkout -b TICKET-ID`
   - Restore stashed changes if any: `git stash pop`
3. Push to remote:
   ```bash
   git push -u origin BRANCH-NAME
   ```

## Rules

- Never push directly to main/master — create a feature branch first
- Always use `-u` to set upstream tracking on first push
- If the branch already has a remote, a regular `git push` suffices
