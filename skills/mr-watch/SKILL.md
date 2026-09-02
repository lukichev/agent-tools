---
name: mr-watch
description: One unattended tick over your open GitLab MRs - rebase the safe ones, then report only what changed since the last tick and notify on new problems. Built to run under /loop. Use when the user says "watch my MRs", "keep my MRs rebased", or wraps it in /loop.
disable-model-invocation: true
---

# MR Watch

One tick of unattended MR maintenance: rebase what is safe, then report the delta. Built for `/loop /mr-watch`. A tick with no change must stay quiet.

Status logic lives in `/mr-status-check`. Rebase logic lives in `/git-rebase-all`. This skill adds the guards, the delta and the pacing.

## Workflow

### 1. Load the previous tick

```bash
git remote get-url origin   # → <host>/<group>/<project>.git
```

State file: `~/.claude/mr-watch/<group>-<project>.json`. Create the directory if absent. No file means the first tick: record state, report the current problems once, then keep quiet.

### 2. Fetch status

Run `/mr-status-check`. Keep the full JSON block, not only the table. It runs forked, so the raw `glab` output never reaches this context.

### 3. Apply the guards

```bash
git rev-parse --abbrev-ref HEAD    # the checked-out branch
git status --porcelain             # empty means clean
```

An MR is **blocked** from unattended rebase when any of these holds:

| Condition | Report as |
|---|---|
| `source_branch` is the checked-out branch | `manual - checked out` |
| `has_conflicts` is true | `manual - conflicts` |
| `unresolved_comments > 0` | `manual - has comments` |

A non-empty `git status --porcelain` blocks every MR (`manual - dirty tree`). Do not stash. Skip step 4.

The last two guards are defaults. The user may lift either one for a tick.

### 4. Rebase the safe set

Read `~/.claude/skills/git-rebase-all/SKILL.md` and follow its steps 2 to 7. Use the JSON from step 2 as its step 1 result. Do not let it call `/mr-status-check` again.

Two changes to its plan:

- After it closes over descendants, drop every blocked MR from the rebase set.
- A dropped MR skips its descendants, like a failed parent. Report those as `skipped (parent blocked)`.

An empty set skips to step 5.

Never resolve a conflict here. A conflict resolution that no human read must not reach the remote. The set holds only server-side rebases, so no worktree isolation is needed and step 7 of `/git-rebase-all` has nothing to clean.

### 5. Report the delta

Compare each MR against the state file. Report only:

- a rebase this tick performed, with the result
- `pipeline` changed
- `unresolved_comments` changed
- `has_conflicts` changed
- `status` changed
- an MR opened or closed since the last tick

```
!6465 PROJ-9572   rebased (server-side), 21 behind → up to date
!6570 PROJ-9670   pipeline: running → failed
!6575 PROJ-9184   manual - 1 new comment from @reviewer
```

Nothing changed: say `no change` and nothing else. Never print the dashboard. The user runs `/mr-status-check` for that.

### 6. Notify

Send at most one `PushNotification` per tick, only for a new item the user would act on now:

- `pipeline` became `failed`
- `unresolved_comments` increased
- `has_conflicts` became true
- `status` became `ready`

Batch every trigger into one message. Send nothing for a rebase that worked, a pipeline still running, or a problem the previous tick reported.

### 7. Save state and set the pace

Write the state file: `iid`, `pipeline`, `unresolved_comments`, `has_conflicts`, `status` per MR, plus the tick time. Store nothing about stacks. `/git-rebase-all` infers those fresh every time.

Inside `/loop` without an interval, close the tick with `ScheduleWakeup`:

| Tick outcome | Delay | `noop` |
|---|---|---|
| A pipeline is running | 300s | false |
| Something changed | 900s | false |
| No change | 1800s | true |

When `/loop` sets a fixed interval, or the skill runs on its own, stop after the report. Do not call `ScheduleWakeup`.

## Rules

- **Rebase only.** Never merge, never close, never comment, never resolve a conflict.
