---
name: mr-status-check
description: Check status of all open MRs authored by the current user. Shows pipeline status, unresolved comments, rebase needs, and merge readiness. Use when the user says "check my MRs", "MR status", "any comments on my MRs?", "do I need to rebase?", or "what needs attention?".
context: fork
---

# MR Status Check

Dashboard view of all your open MRs — comments, pipeline, rebase status, merge readiness.

## Workflow

### 1. Fetch All Open MRs

```bash
glab mr list --author=@me --output json
```

Parse to get: `iid`, `title`, `source_branch`, `target_branch`, `has_conflicts`, `detailed_merge_status`, `blocking_discussions_resolved`, `user_notes_count`, `web_url`.

If no open MRs, inform the user and stop.

### 2. Fetch Details Per MR

For each MR, fetch additional data in parallel where possible:

**Pipeline status** (not in list output):
```bash
glab mr view <iid> --output json
```
Extract `head_pipeline.status` (`success`, `failed`, `running`, `pending`, `manual`, `canceled`, `null`).

**Unresolved discussions**:
```bash
glab api "projects/:fullpath/merge_requests/<iid>/discussions"
```
Count threads where `notes[0].resolvable == true && notes[0].resolved == false`. Also extract the first line of each unresolved comment for the summary.

**Rebase needed** — determine from `has_conflicts` and `detailed_merge_status`:
- `has_conflicts: true` → needs rebase (conflicts)
- `detailed_merge_status: "need_rebase"` → needs rebase (behind target)
- Otherwise → up to date

**Divergence from target** — how far source branch has drifted from its target:
```bash
glab api "projects/:fullpath/merge_requests/<iid>" --jq '.diff_refs.base_sha'
```
Then count commits on target that aren't in source:
```bash
git fetch origin <target_branch> <source_branch> 2>/dev/null
git rev-list --count origin/<source_branch>..origin/<target_branch>
```
This gives the number of commits the source branch is **behind** the target. Display as `N behind` (e.g. `12 behind`, or `up to date` if 0).

### 3. Display Summary Table

```
| MR    | Title                          | Pipeline | Comments     | Rebase | Behind   | Status          |
|-------|--------------------------------|----------|--------------|--------|----------|-----------------|
| !123  | feat(auth): add SSO, DOC-1234  | passed   | 2 unresolved | needed | 34       | needs attention |
| !124  | fix(billing): prorate, DOC-5678| running  | none         | ok     | 12       | waiting         |
| !125  | refactor(deps): luxon, DOC-9175| manual   | none         | ok     | 0        | ready           |
```

**Status column logic:**
- `needs attention` — has unresolved comments OR has conflicts OR behind > 0
- `blocked` — pipeline failed
- `waiting` — pipeline running/pending
- `ready` — pipeline passed (or manual), no unresolved comments, no rebase needed, **behind == 0**
- `draft` — MR is marked as draft

A branch that is behind its target is **not mergeable** — it must be rebased first.

### 4. Show Unresolved Comments Detail

For each MR with unresolved comments, show a brief summary:

```
!123 — 2 unresolved comments:
  - @reviewer (line 42 of src/auth.ts): "Should this handle the refresh token case?"
  - @reviewer (line 88 of src/auth.ts): "Missing null check"
```

Keep it brief — first line of each comment, truncated to 100 chars.

## Output Format

This skill runs in a forked context — only the final message reaches the caller, so it must be self-contained. Always include both:

1. The human-readable summary table and unresolved-comment details
2. A fenced JSON block with one record per MR so callers (like `/git-rebase-all`) can consume it programmatically:

```json
[
  {
    "iid": 123,
    "title": "feat(auth): add SSO, DOC-1234",
    "source_branch": "DOC-1234",
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

Include every open MR in the JSON (even `ready` ones) — `/git-rebase-all` needs the full list to resolve stacked-MR parent relationships.

## Rules

- **Read-only** — never modify MRs, push, or rebase
- Fetch MR details in parallel to minimize latency
- Truncate long titles to 40 chars in the table
- Sort MRs: needs attention first, then waiting, then ready
