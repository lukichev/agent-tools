---
name: git-rebase-all
description: Rebase all open GitLab MRs onto their target branches. Builds a dependency graph from stacked MRs (where one MR's target is another's source) and rebases in waves — parents first, then children — running MRs within each wave in parallel via isolated subagents. Children of rebased parents are always included even if not yet behind. Use when the user says "rebase all my MRs", "rebase all branches", "update all my MRs".
disable-model-invocation: true
---

# Rebase All MRs

Orchestrates rebases for every open MR you authored, respecting stacked-MR dependencies. All rebase logic lives in `/git-rebase` — this skill just plans the waves and spawns subagents.

## Workflow

### 1. Check MR status

Run `/mr-status-check`. Keep the **full MR list** — children of rebased parents may show `behind: 0` initially.

### 2. Build the graph and rebase set

- **Parent**: `parentOf(mr) = the MR whose source_branch == mr.target_branch`. No match → root (targets `main` or similar).
- **Rebase set**: start with MRs where `behind > 0`, then close over descendants (parent's rebase will leave them behind).
- For each MR in the set, record an inclusion reason: `"N behind"` or `"parent rebased"`.

If the set is empty, stop.

### 3. Compute waves

- **Wave 1** = MRs whose parent is not in the set.
- **Wave N+1** = MRs whose parent is in Wave ≤ N.

Show the user the wave plan.

### 4. Fetch upfront

For MRs that need a local rebase (conflicts), fetch their source + target branches now to avoid network races:

```bash
git fetch origin <branch1> <branch2> ...
```

### 5. Spawn subagents — wave by wave

For each wave in order:

1. Spawn one Agent call per MR in the wave, **all in a single message** (parallel within the wave).
   - **No conflicts** → server-side rebase prompt, no `isolation`.
   - **Has conflicts** → local-rebase prompt with `isolation: "worktree"`.
2. **Wait for the wave to complete** before starting the next — child's parent must land on the remote first.
3. If an MR fails, mark its descendants `skipped (parent failed)` and don't spawn them. Other chains continue.

Each subagent prompt must be self-contained.

**Server-side rebase prompt (no conflicts):**

> Rebase MR !<iid> (`<sourceBranch>` → `<targetBranch>`) via GitLab server-side rebase.
>
> 1. `glab api --method PUT "projects/:fullpath/merge_requests/<iid>/rebase"`
> 2. Poll every 5s, **max 60 attempts (5 minutes)**: `glab api "projects/:fullpath/merge_requests/<iid>" --jq '{rebase_in_progress, merge_error}'`. Done when `rebase_in_progress` is false; failed if `merge_error` is set; **timed out** if the cap is reached while still in progress.
> 3. Report: rebased with new SHA, failure reason, or `timed out after 5 minutes` (so the wave can proceed without hanging).

**Local rebase prompt (has conflicts):**

> You are in an isolated worktree. Rebase `<sourceBranch>` onto `<targetBranch>`. Branches are fetched.
>
> 1. `git checkout <sourceBranch>`
> 2. If `git merge-base --is-ancestor origin/<targetBranch> HEAD`, report "up to date" and stop.
> 3. Inspect `git log --oneline origin/<targetBranch>..HEAD`. If foreign commits are present (parent branch squash-merged into target):
>    `git rebase --onto origin/<targetBranch> <first-own-commit>~1 <sourceBranch>`
>    Otherwise: `git rebase origin/<targetBranch>`
> 4. Resolve conflicts (read, fix, `git add`, `git rebase --continue`). If hopeless, `git rebase --abort` and report failure.
> 5. `git push --force-with-lease origin <sourceBranch>`
>
> Report: pushed, up to date, conflicts resolved and pushed, or failure reason.

### 6. Report

```
| MR    | Branch    | Target    | Wave | Reason          | Result                  |
|-------|-----------|-----------|------|-----------------|-------------------------|
| !6465 | PROJ-9572 | main      | 1    | 21 behind       | server-side rebased     |
| !6570 | PROJ-9670 | main      | 1    | 2 behind        | server-side rebased     |
| !6575 | PROJ-9184 | PROJ-9670 | 2    | parent rebased  | server-side rebased     |
| !6580 | PROJ-9574 | PROJ-9184 | 3    | parent rebased  | skipped (parent failed) |
```

### 7. Cleanup

Remove subagent worktree artifacts left by the isolation runs (these are throwaways specific to this skill — handle them here, not in `/git-cleanup`, which would treat their branches as unmerged work to keep):

```bash
git worktree list                     # find .claude/worktrees/agent-* entries
git worktree remove <path> --force    # for each one
git branch -D worktree-agent-*        # delete leftover tracking branches
git worktree prune
```

Then run `/git-cleanup` to prune remote-tracking refs and delete local branches whose MRs have merged — it verifies content actually landed before deleting (survives squash-merges), unlike a raw `: gone]` sweep.

## Rules

- All rebase logic lives in `/git-rebase` — don't duplicate it here.
- Parallel within a wave, sequential between waves — the child's parent must be on the remote before the child rebases.
- Always include descendants of rebased MRs, even if `behind: 0`.
- Parent failure skips its descendants only; other chains continue.
- `isolation: "worktree"` only for conflict MRs.
- Stack relationships are always inferred fresh from `target_branch` — no persisted state.
