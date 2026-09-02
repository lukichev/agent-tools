---
name: git-push
description: Push the current branch to remote. Creates a feature branch from main first if currently on main/master.
argument-hint: "<branch name (optional)>"
---

# Git Push

Push the current branch to the remote. If on main/master, create a feature branch first.

## Workflow

1. Check the current branch:
   ```bash
   git branch --show-current
   ```
2. If on `main` or `master`:
   - Stash uncommitted changes if any: `git stash`
   - Pull latest: `git pull`
   - Detect the ticket ID from the recent commit message, or ask the user
   - Create the feature branch: `git checkout -b TICKET-ID`
   - **Rewind main to the remote**: `git branch -f main origin/main`. A commit made on main is now on both branches. Without this, local main stays ahead of origin and the next push to main leaks it.
   - Restore stashed changes if any: `git stash pop`
3. Push to the remote:
   ```bash
   git push -u origin BRANCH-NAME
   ```

## Rules

- Never push directly to main/master. Create a feature branch first.
