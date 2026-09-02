---
name: git-rebase-all
description: Rebase all open GitLab MRs onto their target branches. Builds a dependency graph from stacked MRs (one MR's target is another's source) and rebases in waves, parents first, then children, with MRs in each wave in parallel via isolated subagents. Children of rebased parents are always included even if not yet behind. Use when the user says "rebase all my MRs", "rebase all branches", "update all my MRs".
disable-model-invocation: true
---

# Rebase All MRs

Rebase every open MR you authored, in dependency order. All rebase logic lives in `/git-rebase`. This skill plans the waves and spawns subagents.

Read `~/.claude/guides/glab-api.md` before you call `glab`.

## Workflow

### 1. Check MR status

Run `/mr-status-check`. Keep the full MR list. Children of rebased parents may show `behind: 0` at first.

### 2. Build the graph and rebase set

- **Parent**: `parentOf(mr) = the MR whose source_branch == mr.target_branch`. No match means root (targets `main` or similar).
- **Rebase set**: start with MRs where `behind > 0`, then add all descendants (the parent's rebase leaves them behind).
- Record an inclusion reason per MR: `"N behind"` or `"parent rebased"`.

If the set is empty, stop.

### 3. Compute waves

- **Wave 1** = MRs whose parent is not in the set.
- **Wave N+1** = MRs whose parent is in Wave ≤ N.

Show the user the wave plan.

### 4. Fetch upfront

For MRs that need a local rebase (conflicts), fetch source and target branches now to avoid network races:

```bash
git fetch origin <branch1> <branch2> ...
```

### 5. Spawn subagents, wave by wave

For each wave in order:

1. Spawn one Agent call per MR in the wave, all in a single message.
   - **No conflicts**: server-side rebase prompt, no `isolation`.
   - **Has conflicts**: local-rebase prompt with `isolation: "worktree"`.
2. Wait for the wave to complete before the next one. The child's parent must land on the remote first.
3. If an MR fails, mark its descendants `skipped (parent failed)` and do not spawn them. Other chains continue.

Each subagent prompt must be self-contained.

**Server-side rebase prompt (no conflicts):**

> Rebase MR !<iid> (`<sourceBranch>` → `<targetBranch>`) via GitLab server-side rebase.
>
> 1. `glab api --method PUT "projects/:fullpath/merge_requests/<iid>/rebase"`
> 2. Poll every 5s, **max 60 attempts (5 minutes)**: `glab api "projects/:fullpath/merge_requests/<iid>?include_rebase_in_progress=true" | jq '{rebase_in_progress, merge_error, sha}'`. Two `glab` traps (it is not `gh`): the `--jq` flag is unsupported, pipe through `jq` instead; and `rebase_in_progress` is omitted unless `?include_rebase_in_progress=true` is in the query string (without it the field reads `null`, never `false`). Done when `rebase_in_progress` is not `true` (`false` or `null`). Failed if `merge_error` is set. **Timed out** if the cap is reached while still in progress.
> 3. Report: rebased with the new SHA (the `sha` field), the failure reason, or `timed out after 5 minutes`.

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
> Report: pushed, up to date, conflicts resolved and pushed, or the failure reason.

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

Remove the worktree artifacts left by the isolation runs. Handle them here, not in `/git-cleanup`, which would keep their branches as unmerged work:

```bash
git worktree list                     # find .claude/worktrees/agent-* entries
git worktree remove <path> --force    # for each one
git branch -D worktree-agent-*        # delete leftover tracking branches
git worktree prune
```

## Rules

- The subagent prompts hold the executable steps. Keep them in step with `/git-rebase`, which owns the strategy.
- Stack relationships are inferred fresh from `target_branch` every run. No persisted state.
