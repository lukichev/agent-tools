---
name: git-rebase
description: Rebase a branch onto its MR target branch (auto-detected) or main. Handles squash-merged parent branches automatically. If not on the branch to rebase, uses a git worktree so the current working directory is undisturbed.
argument-hint: "<source-branch> [onto <target-branch>]"
---

# Git Rebase

Rebase a feature branch onto its target branch. Auto-detects the target from the existing MR, falls back to `main`. Detects and handles the squash-merge scenario where a parent branch was squash-merged into the target.

Read `~/.claude/guides/glab-api.md` before you call `glab`. It holds the flag limits and the API traps that make a wrong result look like a right one.

Works in two modes:
- **In-place** — when already on the branch to rebase
- **Worktree** — when on a different branch (creates a temporary worktree, keeps the current directory untouched)

Both modes support full automated conflict resolution.

## Workflow

### 1. Preflight

```bash
git status --porcelain
git branch --show-current
```

- If already on main/master and no specific branch was requested, warn and stop.
- Determine the **source branch** (the branch to rebase):
  - If the user specified a branch to rebase (e.g., `/git-rebase feat/foo onto main`), use that.
  - Otherwise, use the current branch.
- Determine the **mode**:
  - If the current branch IS the source branch → **in-place mode**
  - If the current branch is NOT the source branch → **worktree mode**

**In-place mode preflight:**
- If a rebase is already in progress (`git status` shows "rebase in progress"), jump to conflict resolution.
- If there are uncommitted changes, stash them:

```bash
git stash push -m "pre-rebase-$(date +%s)"
```

**Worktree mode preflight:**
- If there are uncommitted changes, warn the user but proceed — worktrees won't touch the working directory.

### 2. Determine Target Branch

If the user specified a target branch explicitly, use that. Otherwise, auto-detect:

```bash
# Check if an MR exists for the source branch and get its target
glab mr list --source-branch <source-branch> --output json 2>/dev/null
```

Parse the JSON and extract `target_branch` and `iid` from the first result. `<iid>` below means that value.

- If an MR exists, use its `target_branch` as the rebase target.
- If no MR exists or the command fails, fall back to `main`.

Tell the user which target branch was detected and why.

### 3. Set Up Worktree (worktree mode only)

Branch names can contain `/` (e.g. `feat/foo`), which would break a path like `/tmp/rebase-feat/foo`. Sanitize the branch name for the path by replacing `/` with `-`:

```bash
SOURCE_BRANCH="<source-branch>"
SAFE_BRANCH="${SOURCE_BRANCH//\//-}"
WORKTREE_DIR="/tmp/rebase-${SAFE_BRANCH}"

git fetch origin "$SOURCE_BRANCH"
git worktree add "$WORKTREE_DIR" "origin/$SOURCE_BRANCH" --detach
cd "$WORKTREE_DIR"
git checkout -B "$SOURCE_BRANCH" "origin/$SOURCE_BRANCH"
```

All subsequent git commands run inside `$WORKTREE_DIR`. The original branch name (with `/`) is preserved everywhere except the filesystem path.

### 4. Fetch and Analyse

```bash
git fetch origin <target>
git log --oneline origin/<target>..HEAD
```

Check if already up to date:

```bash
git merge-base --is-ancestor origin/<target> HEAD && echo "up-to-date"
```

If up to date, inform the user and stop (clean up worktree if applicable).

Look at the commit list. Determine whether all commits belong to the source branch or if there are commits from a **parent branch** (different ticket ID or scope).

### 5. Choose Strategy

**Simple case** — all commits belong to the source branch:

```bash
git rebase origin/<target>
```

**Squash-merge case** — commits from a parent branch are present (they were squash-merged into the target and now conflict):

Identify the boundary: the parent of the first commit that belongs to the **source** branch. Then use `--onto`:

```bash
git rebase --onto origin/<target> <first-own-commit>~1 <source-branch>
```

This replays only the source branch's commits onto the target, skipping the parent branch commits that are already in the target via squash-merge.

**How to detect the squash-merge case:**
- Commits from another ticket/branch appear between the source branch's commits and the target
- A plain `git rebase origin/<target>` fails with many conflicts on commits that aren't ours
- The parent branch no longer exists on the remote (`git ls-remote origin <parent-branch>` returns nothing)

### 6. Handle Conflicts

Conflict resolution works the same in both modes — the only difference is the file paths (working directory vs `$WORKTREE_DIR`, which is `/tmp/rebase-<sanitized-branch>`).

- Read the conflicted files (use their full paths in the worktree if applicable)
- Resolve by keeping the correct version (usually ours for our own files, theirs for files we didn't touch)
- `git add <resolved-files>` then `git rebase --continue`
- If more conflicts appear, repeat
- If the rebase is hopeless (e.g., too many unrelated conflicts), `git rebase --abort` and inform the user

### 7. Verify and Push

```bash
# Verify only our commits remain
git log --oneline origin/<target>..HEAD

# Force push (safe — only our branch)
git push --force-with-lease origin <source-branch>
```

### 8. Clean Up

**In-place mode:**
- Restore stash if one was created (`git stash pop`)

**Worktree mode:**

```bash
cd /                          # leave the worktree directory first
git worktree remove "$WORKTREE_DIR" --force
```

If the rebase was aborted (hopeless conflicts), clean up the worktree too.

### 9. Update MR Target (if needed)

If an MR exists and its target branch differs from the rebase target:

```bash
glab mr update <iid> --target-branch <target>
```

## Error Recovery

| Problem | Fix |
|---|---|
| "Cannot rebase: uncommitted changes" | `git stash push -m "temp"` (in-place) or ignore (worktree) |
| "No upstream configured" | `git push -u origin HEAD` after rebase |
| Plain rebase has many conflicts on commits that aren't ours | Abort and use `--onto` strategy (squash-merge case) |
| Conflicts keep recurring | Check for duplicate commits: `git log --oneline origin/<target>..HEAD` |
| Rebase went wrong | `git rebase --abort` restores pre-rebase state |
| Worktree already exists at path | `git worktree remove /tmp/rebase-<sanitized-branch> --force` then retry (replace `/` with `-` in branch name) |

## Rules

- Never rebase main/master itself
- Always use `--force-with-lease` (not `--force`) when pushing
- Always verify the commit list after rebase — the number of own commits should match before and after
- If a plain rebase fails with many conflicts on commits that aren't ours, abort and try the `--onto` strategy before asking the user
- In in-place mode, restore stash after rebase if one was created
- In worktree mode, resolve conflicts using full file paths inside the worktree; clean up the worktree after completion or abort
- Explain what you're doing at each step so the user can follow along
