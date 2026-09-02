---
name: git-cleanup
description: Tidy local git state after upstream branches are merged or deleted. Prunes stale remote-tracking refs, converts clean worktrees back to plain branches, deletes merged branches whose remote is gone, reviews stashes, and retires agent memories for tickets with no local branch. Verifies that work landed (survives squash-merges) before it deletes anything, and never drops a stash or a memory without confirmation. Use when the user says "clean up my branches", "prune merged branches", "tidy git state", "remove old worktrees", "clean up agent memories", or after MRs have been merged.
disable-model-invocation: true
---

# git-cleanup

Reclaim local git state after merges. Verify before you remove. Never destroy a stash or an unmerged branch without explicit sign-off. Finish with a summary of what was pruned, converted, deleted and left alone, and why.

Protected refs, never touched: the current branch, the default branch (`main`/`master`), `production`, and `mr-<IID>` review worktrees with their branches and `refs/mr-review/<IID>` refs. Read the project's `CLAUDE.md` for more protected branch names before you start.

## Setup

Detect the default branch once. Every later step compares against it:

```bash
DEFAULT=$(git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
DEFAULT=${DEFAULT:-main}   # fall back to main if origin/HEAD isn't set
```

## Step 1 - Prune remote-tracking refs

Drop `origin/*` refs for branches deleted upstream. This makes the `: gone]` markers in later steps accurate.

```bash
git fetch --prune
```

## Step 2 - Worktrees

```bash
git worktree list --porcelain
```

Never remove the first entry (the primary checkout) or the worktree you stand in (`git rev-parse --show-toplevel`).

**Review worktrees**, `mr-<IID>` directories from `/mr-review` on a branch of the same name, are protected with that branch and its `refs/mr-review/<IID>` ref. Leave all three and report each as skipped. The branch also reads as `: gone]` and unmerged, so the branch logic below must not touch it.

Report the disk cost of each review tree:

```bash
du -sh <path>
```

The user removes one by hand:

```bash
git worktree remove <path> && git branch -D "mr-<IID>" && git update-ref -d "refs/mr-review/<IID>"
```

For every other worktree:

1. **Protected branch?** If its branch is the default branch, `production`, or a protected name from `CLAUDE.md`, leave it and report it as skipped.
2. **Unfinished work?** If `git -C <path> status --short` is non-empty (uncommitted or untracked files), or a `git stash list` line names its branch, leave it and report it.
3. **Otherwise convert it to a plain branch:**
   ```bash
   git worktree remove <path>
   ```
   If `remove` fails (locked worktree, or one with a submodule), do not `--force`. Report the failure and continue. On success the branch stays in `git branch`. Run the [merge check](#merge-verification) on it. If the branch is `: gone]` after the prune and its work has landed, `git branch -D <branch>`. Otherwise keep the branch and report it.

Then tidy leftover entries:

```bash
git worktree prune
```

## Step 3 - Local branches whose upstream is gone

```bash
git branch -vv
```

Collect branches marked `: gone]`, minus protected refs and those handled in Step 2. Verify that the work landed before you delete.

Do not trust `git branch -d` ancestry or `git cherry`. A squash-merge collapses the branch into one new commit, so both report "not merged". Compare content with the merge check below.

- **Merged** (empty diff): `git branch -D <branch>`.
- **Not merged** (non-empty diff): never auto-delete. Report it as unmerged work for a human decision.

### Merge verification

Check whether every file the branch touched matches the default branch:

```bash
MB=$(git merge-base origin/$DEFAULT <branch>)
if [ -z "$(git diff --name-only "$MB" <branch>)" ]; then
  echo MERGED                                        # branch changed nothing since diverging
else
  # diff only the files the branch touched; -z/xargs -0 keeps paths with spaces intact
  git diff --name-only -z "$MB" <branch> | xargs -0 git diff origin/$DEFAULT <branch> --
fi
```

An empty final diff means merged (squash, rebase or plain merge all collapse to this). A non-empty diff means not merged. Scoping the diff to the touched files keeps a busy `main` from hiding a clean merge, and a later `main` edit only keeps the branch.

> A branch merged into a parent feature branch, not `$DEFAULT`, reads as unmerged here. Tell the user if they work with stacked branches.

## Step 4 - Local branches diverged from a live upstream

After a server-side rebase or force-push, `git branch -vv` shows a live upstream with `[ahead N, behind M]`. The remote is authoritative. The local `ahead` commits are usually pre-rebase twins. Run the [merge check](#merge-verification) with the upstream in place of `origin/$DEFAULT`:

- **Empty diff**: rebased twins, safe to reset the pointer to the upstream.
- **Non-empty diff**: unique local commits. Keep and report. Never `git branch -f`, it discards them silently.

Once all are verified, sync in one pass (skips the current branch, then fast-forwards it):

```bash
cur=$(git symbolic-ref --short HEAD)
git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads | while read -r b u; do
  [ -n "$u" ] && [ "$b" != "$cur" ] && git branch -f "$b" "$u"
done
git merge --ff-only @{u}   # updates the branch you're standing on
```

## Step 5 - Stashes

```bash
git stash list
```

A dropped stash is unrecoverable. Never drop one without explicit confirmation. For each stash, gather evidence on whether its content is already in the default branch:

```bash
git stash show --stat <stash>      # which files, how much
git stash show -p <stash>          # the actual patch - pull out a few distinctive added lines
```

Check whether those distinctive added lines exist in the default branch's version of the files:

```bash
git show origin/$DEFAULT:<file> | grep -F "<distinctive added line>"
```

Present each stash with its summary line, file stat, a couple of distinctive added lines, and your assessment (**likely already merged** or **unique unsaved work**). Use `AskUserQuestion` to confirm which to drop, defaulting to keep. Only on explicit approval:

```bash
git stash drop <stash>
```

When unsure, keep it.

## Step 6 - Agent memories for finished tickets

Retire per-ticket memories in `.claude/agent-memory/atlassian-researcher/` (a `<TICKET-ID>/` directory per ticket) and `.claude/agent-memory/code-reviewer/` (flat files). Skip the step when neither directory exists.

Build the live ticket set from branch names only. A `git branch -v` line also carries the commit subject, so `main` would protect the last ticket that landed:

```bash
LIVE=$(git branch --format='%(refname:short)' | grep -oiE '[A-Z]{2,}-[0-9]+' | tr -d '-' | tr '[:lower:]' '[:upper:]' | sort -u)
```

A memory is a candidate when it names at least one ticket and none of them is in `LIVE`. Collect ids from the filename and the body, because an epic memory names its children:

```bash
grep -hoiE '[A-Z]{2,}-?[0-9]{4,}' <file> | tr -d '-' | tr '[:lower:]' '[:upper:]' | sort -u
```

Two exclusions, read from the frontmatter `type:`:

- `type: feedback` is never a candidate. A standing preference outlives its ticket.
- A memory that names no ticket is never a candidate.

`.claude/` is git-ignored in most projects, so the delete has no undo. Confirm with `AskUserQuestion` as for a stash, defaulting to keep. List each candidate with its ticket ids and its `description:` line.

On approval, per memory: delete the file or the `<TICKET-ID>/` directory, delete its line from that agent's `MEMORY.md`, then clear dead links with `grep -rn "\[\[<deleted-name>\]\]" .claude/agent-memory/`. Never delete `MEMORY.md` itself.

## Summary

Close with a table of every item and its disposition:

```
| Item                        | Type      | Action                  | Why                                  |
|-----------------------------|-----------|-------------------------|--------------------------------------|
| origin/feat/PROJ-1020       | remote    | pruned                  | deleted upstream                     |
| /tmp/wt-PROJ-1100           | worktree  | converted → branch      | clean; branch kept (not yet merged)  |
| /tmp/wt-PROJ-1099           | worktree  | converted, branch -D    | clean, gone on remote, merged        |
| /tmp/wt-PROJ-1200           | worktree  | left alone              | uncommitted changes                  |
| /tmp/mr-7008                | worktree  | left alone (88M)        | MR review tree, protected            |
| PROJ-1099                   | branch    | deleted (branch -D)     | gone + content matches main          |
| PROJ-1150                   | branch    | KEPT - unmerged         | gone on remote but diff non-empty    |
| PROJ-1300                   | branch    | synced (branch -f)      | diverged; local commits are rebased twins on remote |
| PROJ-1301                   | branch    | KEPT - unique local work| diverged; local-only commits not on remote |
| stash@{0}                   | stash     | dropped (confirmed)     | content already in main              |
| stash@{1}                   | stash     | KEPT                    | unique unsaved work                  |
| researcher/PROJ-1099        | memory    | deleted (confirmed)     | no local branch for PROJ-1099        |
| reviewer/project_proj1150…  | memory    | KEPT                    | PROJ-1150 branch still checked out   |
```

## Rules

- Never delete a branch that is not both gone on remote and proven merged by content diff.
- Never `git branch -f` a diverged branch until its local commits are proven to add nothing.
- Never `--force` a `git worktree remove`. Report the failure and continue.
- Never drop a stash without showing its content and getting confirmation.
- Never delete an agent memory without confirmation, and never delete a `type: feedback` one.
