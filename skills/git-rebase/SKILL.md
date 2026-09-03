---
name: git-rebase
description: Rebase a branch onto its MR target branch (auto-detected) or main. Handles squash-merged parent branches automatically. If not on the branch to rebase, uses a git worktree so the current working directory is undisturbed.
argument-hint: "<source-branch> [onto <target-branch>]"
---

# Git Rebase

Rebase a feature branch onto its target. Detects the target from the existing MR, falls back to `main`. Handles a parent branch that was squash-merged into the target.

Read `~/.claude/guides/glab-api.md` before you call `glab`.

Two modes, both with automated conflict resolution:
- **In-place**: already on the branch to rebase.
- **Worktree**: on a different branch. A temporary worktree keeps the current directory untouched.

## Workflow

### 1. Preflight

```bash
git status --porcelain
git branch --show-current
```

- On main/master with no branch requested: warn and stop.
- **Source branch**: the branch the user named (`/git-rebase feat/foo onto main`), else the current branch.
- **Mode**: current branch is the source means in-place, otherwise worktree.

In-place:
- If a rebase is already in progress (`git status` shows "rebase in progress"), jump to conflict resolution.
- Stash uncommitted changes:

```bash
git stash push -m "pre-rebase-$(date +%s)"
```

Worktree: warn about uncommitted changes but proceed. The worktree does not touch the working directory.

### 2. Determine Target Branch

If the user named a target, use it. Otherwise:

```bash
# Check if an MR exists for the source branch and get its target
glab mr list --source-branch <source-branch> --output json 2>/dev/null
```

Take `target_branch` and `iid` from the first result. `<iid>` below means that value.

- MR exists: its `target_branch` is the rebase target.
- No MR, or the command fails: fall back to `main`.

Tell the user which target was detected and why.

### 3. Set Up Worktree (worktree mode only)

A branch name can contain `/` (`feat/foo`), which breaks a path like `/tmp/rebase-feat/foo`. Replace `/` with `-` in the path only:

```bash
SOURCE_BRANCH="<source-branch>"
SAFE_BRANCH="${SOURCE_BRANCH//\//-}"
WORKTREE_DIR="/tmp/rebase-${SAFE_BRANCH}"

git fetch origin "$SOURCE_BRANCH"
git worktree add "$WORKTREE_DIR" "origin/$SOURCE_BRANCH" --detach
cd "$WORKTREE_DIR"
git checkout -B "$SOURCE_BRANCH" "origin/$SOURCE_BRANCH"
```

All later git commands run inside `$WORKTREE_DIR`. The branch name keeps its `/` everywhere except the path.

### 4. Fetch and Analyse

```bash
git fetch origin <target>
git log --oneline origin/<target>..HEAD
```

Check if already up to date:

```bash
git merge-base --is-ancestor origin/<target> HEAD && echo "up-to-date"
```

If up to date, tell the user and stop (remove the worktree if one exists).

Read the commit list. Decide whether every commit belongs to the source branch, or some come from a **parent branch** (different ticket ID or scope).

### 5. Choose Strategy

**Simple case**, all commits belong to the source branch:

```bash
git rebase origin/<target>
```

**Squash-merge case**, parent branch commits are present (already in the target via squash-merge, and now conflicting). Find the boundary: the parent of the first commit that belongs to the source branch. Then:

```bash
git rebase --onto origin/<target> <first-own-commit>~1 <source-branch>
```

This replays only the source branch's commits and skips the parent's.

Signs of the squash-merge case:
- Commits from another ticket or branch sit between the source commits and the target
- A plain `git rebase origin/<target>` fails with many conflicts on commits that are not ours
- The parent branch is gone from the remote (`git ls-remote origin <parent-branch>` returns nothing)

### 6. Handle Conflicts

Same in both modes. Only the file paths differ (working directory, or `$WORKTREE_DIR` = `/tmp/rebase-<sanitized-branch>`).

- Read the conflicted files, with full worktree paths when applicable
- Keep the correct version: usually ours for our own files, theirs for files we did not touch
- `git add <resolved-files>`, then `git rebase --continue`
- Repeat while conflicts appear
- If the conflicts cannot be resolved (many unrelated conflicts), `git rebase --abort` and tell the user

### 7. Verify and Push

```bash
# Verify only our commits remain
git log --oneline origin/<target>..HEAD

# Force push (safe - only our branch)
git push --force-with-lease origin <source-branch>
```

The count of own commits must match before and after.

### 8. Clean Up

In-place: `git stash pop` if a stash was created.

Worktree, also after an abort:

```bash
cd /                          # leave the worktree directory first
git worktree remove "$WORKTREE_DIR" --force
```

### 9. Update MR Target (if needed)

If an MR exists and its target differs from the rebase target:

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
| Rebase failed | `git rebase --abort` restores the pre-rebase state |
| Worktree already exists at path | `git worktree remove /tmp/rebase-<sanitized-branch> --force` then retry (replace `/` with `-` in branch name) |

## Rules

- Never rebase main/master itself.
- Push with `--force-with-lease`, never `--force`.
- If a plain rebase fails with many conflicts on commits that are not ours, abort and try `--onto` before you ask the user.
- Tell the user what you do at each step.
