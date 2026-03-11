---
name: git-rebase-all
description: Rebase all open GitLab MRs onto their target branches in parallel. Fetches MRs authored by the current user, spawns an isolated subagent per MR using Agent tool worktree isolation, and reports results. Use when the user says "rebase all my MRs", "rebase all branches", "update all my MRs", or "rebase everything".
disable-model-invocation: true
---

# Rebase All MRs

Orchestrator that rebases every open MR you authored **in parallel**. All rebase logic lives in `/git-rebase` — this skill lists MRs, spawns isolated subagents, and collects results.

## Workflow

### 1. Preflight

```bash
git branch --show-current
```

Record the current branch name for context.

### 2. Check MR Status

Run `/mr-status-check` first to show the user a dashboard of all their MRs — pipeline status, unresolved comments, rebase needs.

From the status check results, classify MRs that need rebasing (behind > 0) into two groups:

- **No conflicts** (`has_conflicts: false`) → server-side rebase via GitLab API
- **Has conflicts** (`has_conflicts: true`) → local rebase via subagent with `/git-rebase`

If no MRs need rebasing, inform the user and stop.

### 3. Server-Side Rebase (No Conflicts)

For MRs behind their target but with no conflicts, trigger GitLab's server-side rebase — faster, no local checkout needed:

```bash
glab api --method PUT "projects/:fullpath/merge_requests/<iid>/rebase"
```

Returns `{"rebase_in_progress": true}`. Trigger all eligible ones in parallel, then poll until done:

```bash
glab api "projects/:fullpath/merge_requests/<iid>"
```

Check `rebase_in_progress` — when it becomes `null` or `false`, rebase is done. If `merge_error` is set, the rebase failed (may need local conflict resolution as fallback).

### 4. Local Rebase (Conflicts)

For MRs with conflicts, fetch all source and target branches upfront:

```bash
git fetch origin <branch1> <branch2> <branch3> ...
```

Then spawn one Agent tool call per MR, all in a **single message** so they run in parallel. Use `isolation: "worktree"` on each Agent call — this gives each subagent its own isolated copy of the repo automatically.

Each subagent prompt should include the full rebase instructions (the subagent won't have skill context):

> You are in an isolated worktree. Rebase branch `<sourceBranch>` onto `<targetBranch>`. Branches are already fetched. Follow these steps:
>
> 1. `git checkout <sourceBranch>`
> 2. Check if already up to date: `git merge-base --is-ancestor origin/<targetBranch> HEAD` — if yes, report "already up to date" and stop.
> 3. Analyse commits: `git log --oneline origin/<targetBranch>..HEAD`. Check if all commits belong to `<sourceBranch>` or if there are commits from a parent branch (different ticket ID/scope).
> 4. Rebase:
>    - **Simple case** (all commits are ours): `git rebase origin/<targetBranch>`
>    - **Squash-merge case** (commits from a parent branch are present — different ticket ID, parent branch deleted from remote): identify the first commit that belongs to our branch, then `git rebase --onto origin/<targetBranch> <first-own-commit>~1 <sourceBranch>`
> 5. If conflicts occur, resolve them: read the conflicted files, fix them, `git add`, `git rebase --continue`. Repeat if more conflicts appear. If hopeless (too many unrelated conflicts), `git rebase --abort` and report failure.
> 6. Verify: `git log --oneline origin/<targetBranch>..HEAD`
> 7. Push: `git push --force-with-lease origin <sourceBranch>`
>
> Report back: rebased and pushed, already up to date, conflicts resolved and pushed, or failed with reason.

The Agent tool's worktree isolation handles creation and cleanup — no manual worktree management needed.

### 5. Collect Results

Wait for all subagents to complete. Collect each result.

### 6. Report Results

Show a summary table:

```
| MR    | Branch              | Target | Result                         |
|-------|---------------------|--------|--------------------------------|
| !123  | feat/new-feature    | main   | rebased and pushed             |
| !124  | fix/login-bug       | main   | already up to date             |
| !125  | feat/dashboard      | dev    | conflicts resolved and pushed  |
| !126  | feat/current-work   | main   | failed — aborted               |
```

### 7. Final Cleanup

The Agent tool's `isolation: "worktree"` leaves worktrees and tracking branches behind when agents make changes. Clean up both:

```bash
# Remove worktree directories
git worktree list   # find .claude/worktrees/agent-* entries
git worktree remove <path> --force   # for each one

# Delete leftover tracking branches
git branch -D worktree-agent-*   # delete all worktree-agent branches

# Prune any stale references
git worktree prune
```

## Rules

- All rebase logic (strategies, conflict resolution, push) is owned by `/git-rebase` — don't duplicate it here
- Always run `/mr-status-check` first to show the full picture before rebasing
- Spawn all rebases in a **single message** with multiple Agent tool calls using `isolation: "worktree"` so they run concurrently in isolated copies
- Fetch all branches upfront before spawning to avoid network race conditions
- Only rebase MRs that need it — skip ones already up to date unless the user explicitly asks for all
