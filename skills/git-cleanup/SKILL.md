---
name: git-cleanup
description: Tidy local git state after upstream branches are merged or deleted — prune stale remote-tracking refs, convert clean worktrees back to plain branches, delete fully-merged branches whose remote is gone, and review stashes. Verifies work actually landed (survives squash-merges) before deleting anything, and never drops a stash without confirmation. Use when the user says "clean up my branches", "prune merged branches", "tidy git state", "remove old worktrees", or after MRs have been merged.
disable-model-invocation: true
---

# git-cleanup

Reclaim local git state after merges. The guiding principle: **deleting is easy, recovering is not** — so verify before removing, and never destroy unrecoverable work (stashes, unmerged branches) without explicit sign-off. Always finish with a summary of what was pruned, converted, deleted, and left alone — and why.

Protected refs are never touched: the **current branch**, the repo's **default branch** (`main`/`master`), and `production`. Read the project's `CLAUDE.md` for any additional protected branch names before starting.

## Setup

Detect the default integration branch once — everything downstream compares against it:

```bash
DEFAULT=$(git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
DEFAULT=${DEFAULT:-main}   # fall back to main if origin/HEAD isn't set
```

## Step 1 — Prune remote-tracking refs

Sync with the remote and drop `origin/*` refs for branches deleted upstream. This is what makes the `: gone]` markers in later steps accurate.

```bash
git fetch --prune
```

## Step 2 — Worktrees

```bash
git worktree list --porcelain
```

The **first** entry is the primary checkout — never remove it. Also never remove the worktree you're standing in (`git rev-parse --show-toplevel`). For every *other* worktree:

1. **Holds a protected branch?** If its branch is the default branch, `production`, or any protected name from `CLAUDE.md`, **leave it** — a worktree someone keeps for a protected branch is almost always deliberate. Note it as intentionally skipped.
2. **Has unfinished work?** If `git -C <path> status --short` is non-empty (uncommitted changes *or* untracked files), or a stash references its branch (`git stash list` line mentioning the branch), **leave it and report it**. Removing it would strand that work.
3. **Otherwise convert it to a regular branch** — drop the worktree directory while keeping the branch as a normal local branch:
   ```bash
   git worktree remove <path>
   ```
   If `remove` fails (a locked worktree, or one containing a submodule), **do not `--force`** — report the failure and move on to the next worktree. Forcing could discard work the lock was protecting. On success the branch stays in `git branch`; then run the [merge check](#merge-verification) against it: if the branch is **gone on remote** (it'll show as `: gone]` after the prune) **and** its work has landed, delete it with `git branch -D <branch>`. If it's not gone or not merged, keep the branch and note it.

After removing worktrees, tidy any leftover administrative entries:

```bash
git worktree prune
```

## Step 3 — Local branches whose upstream is gone

```bash
git branch -vv
```

Collect branches marked `: gone]` (their tracked remote branch was deleted) — excluding protected refs and any already handled in Step 2. For each, **verify the work actually landed before deleting.**

Do **not** trust `git branch -d` ancestry or `git cherry` — a squash-merge collapses the branch's commits into one new commit on the default branch, so neither sees the original commits and both wrongly report "not merged." Compare *content* instead, via the merge check below.

- **Merged** (empty diff) → `git branch -D <branch>`.
- **Not merged** (non-empty diff) → **never auto-delete.** Report it as unmerged work that needs a human decision. A `: gone]` branch with real unmerged changes is exactly the kind of thing that's painful to lose.

### Merge verification

For a branch, check whether everything it touched is already reflected in the default branch:

```bash
MB=$(git merge-base origin/$DEFAULT <branch>)
if [ -z "$(git diff --name-only "$MB" <branch>)" ]; then
  echo MERGED                                        # branch changed nothing since diverging
else
  # diff only the files the branch touched; -z/xargs -0 keeps paths with spaces intact
  git diff --name-only -z "$MB" <branch> | xargs -0 git diff origin/$DEFAULT <branch> --
fi
```

An **empty** final diff means the branch's versions of those files are identical to the default branch — fully merged (squash, rebase, or plain merge all collapse to this). **Non-empty** means there's still unmerged content; treat as not merged.

Why scope the diff to just those files: comparing only the files the branch touched ignores everything the default branch advanced independently, so an unrelated busy `main` doesn't mask a clean merge. The failure mode is one-directional and safe — if `main` later re-edited one of those files, the diff is non-empty and the branch is *kept*, never wrongly deleted.

> Note: this compares against the default branch. A branch that was merged into a *parent* feature branch rather than `$DEFAULT` will read as unmerged here — which is the safe direction (reported, not deleted). If the user works with stacked branches, mention this so they can decide.

## Step 4 — Stashes

```bash
git stash list
```

Stashes are the one thing here that's effectively unrecoverable once dropped, so **never drop one blindly, and never without explicit confirmation.** For each stash, gather evidence and assess whether its content already exists in the default branch:

```bash
git stash show --stat <stash>      # which files, how much
git stash show -p <stash>          # the actual patch — pull out a few distinctive added lines
```

To judge "already in main," check whether those distinctive added lines are present in the default branch's version of the affected files:

```bash
git show origin/$DEFAULT:<file> | grep -F "<distinctive added line>"
```

Present each stash with: its summary line, the file stat, a couple of its distinctive added lines, and your assessment (**likely already merged** vs. **looks like unique unsaved work**). Then use `AskUserQuestion` to confirm which, if any, to drop — defaulting to keeping. Only on explicit approval:

```bash
git stash drop <stash>
```

When unsure, keep it. A lingering stash costs nothing; a dropped one is gone.

## Summary

Always close with a table of every item and its disposition:

```
| Item                        | Type      | Action                  | Why                                  |
|-----------------------------|-----------|-------------------------|--------------------------------------|
| origin/feat/PROJ-1020       | remote    | pruned                  | deleted upstream                     |
| /tmp/wt-PROJ-1100           | worktree  | converted → branch      | clean; branch kept (not yet merged)  |
| /tmp/wt-PROJ-1099           | worktree  | converted, branch -D    | clean, gone on remote, merged        |
| /tmp/wt-PROJ-1200           | worktree  | left alone              | uncommitted changes                  |
| PROJ-1099                   | branch    | deleted (branch -D)     | gone + content matches main          |
| PROJ-1150                   | branch    | KEPT — unmerged         | gone on remote but diff non-empty    |
| stash@{0}                   | stash     | dropped (confirmed)     | content already in main              |
| stash@{1}                   | stash     | KEPT                    | unique unsaved work                  |
```

## Rules

- Protected always: current branch, default branch (`main`/`master`), `production`, plus any named in the project's `CLAUDE.md`.
- Verify merges by content diff, not ancestry — squash-merges defeat `git branch -d` and `git cherry`.
- Auto-delete only branches that are both **gone on remote** and **proven merged**. Unmerged `: gone]` branches are reported, never deleted.
- Worktrees holding a protected branch, or with uncommitted changes, untracked files, or an associated stash, are left untouched and reported.
- Never `--force` a `git worktree remove`; if it fails (locked or submodule), report and continue.
- Never drop a stash without showing its content and getting explicit confirmation. Default to keeping.
- Explain each action as you go, and always end with the disposition summary.
