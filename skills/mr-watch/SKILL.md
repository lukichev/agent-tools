---
name: mr-watch
description: One unattended tick over your open GitLab MRs — rebase the safe ones, then report only what changed since the last tick and notify on new problems. Built to run under /loop. Use when the user says "watch my MRs", "keep my MRs rebased", or wraps it in /loop.
disable-model-invocation: true
---

# MR Watch

One tick of unattended MR maintenance: rebase what is safe to rebase, then report the delta.

Designed for `/loop /mr-watch`. A tick must be quiet when nothing changed — an unattended loop that reports every tick is noise, and it spends a turn to say nothing.

All status logic lives in `/mr-status-check`. All rebase logic lives in `/git-rebase-all`. This skill adds the guards, the delta and the pacing.

## Workflow

### 1. Load the previous tick

Derive the state path from the remote:

```bash
git remote get-url origin   # → <host>/<group>/<project>.git
```

State file: `~/.claude/mr-watch/<group>-<project>.json`. Create the directory if it is absent. A missing file means this is the first tick — record state and report the current problems once, then keep quiet.

### 2. Fetch status

Run `/mr-status-check`. Keep the **full JSON block**, not just the table. It runs forked, so the raw `glab` output never reaches this context.

### 3. Apply the guards

Read local git state once:

```bash
git rev-parse --abbrev-ref HEAD    # the checked-out branch
git status --porcelain             # empty means clean
```

An MR is **blocked** from unattended rebase when any of these holds:

| Condition | Report as |
|---|---|
| `source_branch` is the checked-out branch | `manual — checked out` |
| `has_conflicts` is true | `manual — conflicts` |
| `unresolved_comments > 0` | `manual — has comments` |

If `git status --porcelain` is not empty, every MR is blocked (`manual — dirty tree`). Skip step 4 and go to step 5.

The last two guards are defaults. The user may lift either one for a tick; then that condition no longer blocks.

### 4. Rebase the safe set

Read `~/.claude/skills/git-rebase-all/SKILL.md` and follow its steps 2 to 7. Use the JSON from step 2 as its step 1 result — do not let it call `/mr-status-check` again.

Two changes to its plan:

- After it closes over descendants, drop every blocked MR from the rebase set.
- A dropped MR skips its own descendants, the same way a failed parent does. Report those as `skipped (parent blocked)`.

If the resulting set is empty, skip to step 5.

Never resolve a conflict in this skill. A conflict resolution that no human read must not reach the remote.

### 5. Report the delta

Compare each MR against its record in the state file. Report only these:

- a rebase this tick performed, with the result
- `pipeline` changed
- `unresolved_comments` changed
- `has_conflicts` changed
- `status` changed
- an MR opened or closed since the last tick

```
!6465 PROJ-9572   rebased (server-side), 21 behind → up to date
!6570 PROJ-9670   pipeline: running → failed
!6575 PROJ-9184   manual — 1 new comment from @reviewer
```

If nothing on that list changed, say `no change` and nothing else. Never re-print the full dashboard.

### 6. Notify

Send one `PushNotification` only when the tick found a new item the user would act on now:

- `pipeline` became `failed`
- `unresolved_comments` increased
- `has_conflicts` became true
- `status` became `ready`

Batch every trigger into one message. Send nothing for a rebase that worked, for a pipeline that is still running, or for a problem the previous tick already reported.

### 7. Save state and set the pace

Write the state file: `iid`, `pipeline`, `unresolved_comments`, `has_conflicts`, `status` per MR, plus the tick time. Store nothing about stacks — `/git-rebase-all` infers those fresh every time.

When this runs inside `/loop` without an interval, close the tick with `ScheduleWakeup`:

| Tick outcome | Delay | `noop` |
|---|---|---|
| A pipeline is running | 300s | false |
| Something changed | 900s | false |
| No change | 1800s | true |

When `/loop` sets a fixed interval, or when the skill runs on its own, stop after the report. The loop owns the cadence in that case — do not call `ScheduleWakeup`.

## Rules

- **Rebase only.** Never merge, never close, never comment, never resolve a conflict.
- A dirty working tree blocks every rebase. Report it, do not stash.
- The rebase set holds only server-side rebases, so no worktree isolation is needed and step 7 of `/git-rebase-all` has nothing to clean.
- Report the delta, never the dashboard. The user runs `/mr-status-check` when they want the full picture.
- One notification per tick at most.
