---
name: git-rebase
description: Rebase current branch onto main (or another target). Handles squash-merged parent branches automatically.
---

# Rebase

Rebase the current feature branch onto `main` (or a specified target branch). Detects and handles the squash-merge scenario where a parent branch was squash-merged into the target.

## Workflow

### 1. Preflight

```bash
git status --porcelain
git branch --show-current
```

- If already on main/master, warn and stop.
- If a rebase is already in progress (`git status` shows "rebase in progress"), jump to conflict resolution.
- If there are uncommitted changes, stash them:

```bash
git stash push -m "pre-rebase-$(date +%s)"
```

### 2. Fetch and Analyse

```bash
git fetch origin <target>          # default: main
git log --oneline origin/<target>..HEAD
```

Look at the commit list. Determine whether all commits belong to the current branch or if there are commits from a **parent branch** (different ticket ID or scope).

### 3. Choose Strategy

**Simple case** — all commits belong to the current branch:

```bash
git rebase origin/<target>
```

**Squash-merge case** — commits from a parent branch are present (they were squash-merged into the target and now conflict):

Identify the boundary: the parent of the first commit that belongs to the **current** branch. Then use `--onto`:

```bash
git rebase --onto origin/<target> <first-own-commit>~1 <current-branch>
```

This replays only the current branch's commits onto the target, skipping the parent branch commits that are already in the target via squash-merge.

**How to detect the squash-merge case:**
- Commits from another ticket/branch appear between the current branch's commits and the target
- A plain `git rebase origin/<target>` fails with many conflicts on commits that aren't ours
- The parent branch no longer exists on the remote (`git ls-remote origin <parent-branch>` returns nothing)

### 4. Handle Conflicts

If conflicts occur during rebase:
- Read the conflicted files
- Resolve by keeping the correct version (usually ours for our own files, theirs for files we didn't touch)
- `git add <resolved-files>` then `git rebase --continue`
- If the rebase is hopeless, `git rebase --abort` and inform the user

### 5. Verify and Push

```bash
# Verify only our commits remain
git log --oneline origin/<target>..HEAD

# Force push (safe — only our branch)
git push --force-with-lease origin <current-branch>
```

### 6. Update MR Target (if needed)

If an MR exists and its target branch differs from the rebase target:

```bash
glab mr list --source-branch <current-branch>
glab mr update <MR-NUMBER> --target-branch <target>
```

## Parameters

The user may optionally specify:
- **Target branch** — defaults to `main`. Example: `/git-rebase feature/base` rebases onto `feature/base`.

Detect the target from the argument. If no argument, use `main`.

## Error Recovery

| Problem | Fix |
|---|---|
| "Cannot rebase: uncommitted changes" | `git stash push -m "temp"` |
| "No upstream configured" | `git push -u origin HEAD` after rebase |
| Plain rebase has many conflicts on commits that aren't ours | Abort and use `--onto` strategy (squash-merge case) |
| Conflicts keep recurring | Check for duplicate commits: `git log --oneline origin/<target>..HEAD` |
| Rebase went wrong | `git rebase --abort` restores pre-rebase state |

## Rules

- Never rebase main/master itself
- Always use `--force-with-lease` (not `--force`) when pushing
- Always verify the commit list after rebase — the number of own commits should match before and after
- If a plain rebase fails with many conflicts on commits that aren't ours, abort and try the `--onto` strategy before asking the user
- Restore stash after rebase if one was created (`git stash pop`)
- Explain what you're doing at each step so the user can follow along
