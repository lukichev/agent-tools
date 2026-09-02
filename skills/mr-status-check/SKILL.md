---
name: mr-status-check
description: Check status of all open MRs authored by the current user. Shows pipeline status, unresolved comments, rebase needs, and merge readiness. Use when the user says "check my MRs", "MR status", "any comments on my MRs?", "do I need to rebase?", or "what needs attention?".
context: fork
---

# MR Status Check

Dashboard of your open MRs: comments, pipeline, rebase status, merge readiness. Read-only. Never modify an MR, push or rebase.

Read `~/.claude/guides/glab-api.md` before you call `glab`.

## Workflow

### 1. Fetch all open MRs

```bash
glab mr list --author=@me --output json
```

Keep: `iid`, `title`, `source_branch`, `target_branch`, `has_conflicts`, `detailed_merge_status`, `blocking_discussions_resolved`, `user_notes_count`, `web_url`.

No open MRs: say so and stop.

### 2. Fetch details per MR

Issue the calls for every MR in one message, so they run together. Filter each in the pipe.

**Pipeline and merge status** (not in the list output):
```bash
glab mr view <iid> --output json \
  | jq '{pipeline: .head_pipeline.status, merge: .detailed_merge_status}'
```
`pipeline` is `success`, `failed`, `running`, `pending`, `manual`, `canceled` or `null`.

**Unresolved discussions**:
```bash
glab api "projects/:fullpath/merge_requests/<iid>/discussions?per_page=100" \
  | jq '[.[] | select(.notes[0].system | not)
              | select(.notes[0].resolvable and (.notes[0].resolved | not))
              | {author: .notes[0].author.username, path: .notes[0].position.new_path,
                 line: .notes[0].position.new_line, body: .notes[0].body[:100]}]'
```
The `system` filter is required, per the glab guide. Count what remains.

**Rebase needed**: map `detailed_merge_status` per the glab guide. Take it from the single-MR GET above, never from the list response.

**Behind target**: fetch every branch once, before the loop:
```bash
git fetch origin <all-source-and-target-branches> 2>/dev/null
```
Then per MR:
```bash
git rev-list --count origin/<source_branch>..origin/<target_branch>
```
Display as `N behind`, or `up to date` when 0.

### 3. Summary table

```
| MR    | Title                          | Pipeline | Comments     | Rebase | Behind   | Status          |
|-------|--------------------------------|----------|--------------|--------|----------|-----------------|
| !123  | feat(auth): add SSO, PROJ-1234  | passed   | 2 unresolved | needed | 34       | needs attention |
| !124  | fix(billing): prorate, PROJ-5678| running  | none         | ok     | 12       | waiting         |
| !125  | refactor(deps): luxon, PROJ-9175| manual   | none         | ok     | 0        | ready           |
```

Truncate titles to 40 chars. Sort: needs attention, then waiting, then ready.

**Status column.** Evaluate in this order and take the first match:

1. `draft`: MR is marked as draft
2. `blocked`: pipeline failed
3. `needs attention`: unresolved comments, or conflicts, or behind > 0
4. `waiting`: pipeline running or pending
5. `ready`: pipeline passed or manual, no unresolved comments, no rebase needed, behind == 0

A branch behind its target is not mergeable until it is rebased.

### 4. Unresolved comment detail

For each MR with unresolved comments, first line of each comment, truncated to 100 chars:

```
!123 - 2 unresolved comments:
  - @reviewer (line 42 of src/auth.ts): "Should this handle the refresh token case?"
  - @reviewer (line 88 of src/auth.ts): "Missing null check"
```

## Output Format

This skill runs forked. Only the final message reaches the caller, so it must hold both:

1. The summary table and the unresolved comment detail.
2. A fenced JSON block with one record per MR, for callers such as `/git-rebase-all`:

```json
[
  {
    "iid": 123,
    "title": "feat(auth): add SSO, PROJ-1234",
    "source_branch": "PROJ-1234",
    "target_branch": "main",
    "pipeline": "success",
    "unresolved_comments": 2,
    "has_conflicts": false,
    "detailed_merge_status": "need_rebase",
    "behind": 34,
    "status": "needs attention",
    "web_url": "https://gitlab.example.com/group/project/-/merge_requests/123"
  }
]
```

Include every open MR in the JSON, `ready` ones too. `/git-rebase-all` needs the full list to resolve stacked-MR parents.
