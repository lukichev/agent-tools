---
name: mr-status-check
description: Check status of all open MRs authored by the current user. Shows pipeline status, unresolved comments, rebase needs, and merge readiness. Use when the user says "check my MRs", "MR status", "any comments on my MRs?", "do I need to rebase?", or "what needs attention?".
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

### 3. Display Summary Table

```
| MR    | Title                          | Pipeline | Comments | Rebase   | Status          |
|-------|--------------------------------|----------|----------|----------|-----------------|
| !123  | feat(auth): add SSO, DOC-1234  | passed   | 2 unresolved | needed   | needs attention |
| !124  | fix(billing): prorate, DOC-5678| running  | none     | ok       | waiting         |
| !125  | refactor(deps): luxon, DOC-9175| manual   | none     | ok       | ready           |
```

**Status column logic:**
- `needs attention` — has unresolved comments OR has conflicts
- `blocked` — pipeline failed
- `waiting` — pipeline running/pending
- `ready` — pipeline passed (or manual), no unresolved comments, no rebase needed
- `draft` — MR is marked as draft

### 4. Show Unresolved Comments Detail

For each MR with unresolved comments, show a brief summary:

```
!123 — 2 unresolved comments:
  - @reviewer (line 42 of src/auth.ts): "Should this handle the refresh token case?"
  - @reviewer (line 88 of src/auth.ts): "Missing null check"
```

Keep it brief — first line of each comment, truncated to 100 chars.

### 5. Actionable Suggestions

Based on the results, suggest next steps:

- MRs needing rebase → "Run `/git-rebase-all` to rebase all branches"
- MRs with unresolved comments → "Run `/mr-review <iid>` to see full discussion"
- MRs ready to merge → "These MRs are ready to merge"

## Output Format

Return the summary table AND the per-MR details as structured data so callers (like `/git-rebase-all`) can consume programmatically. Always show the human-readable table to the user.

## Rules

- Read-only — never modify MRs, push, or rebase
- Fetch MR details in parallel to minimize latency
- Truncate long titles to 40 chars in the table
- Sort MRs: needs attention first, then waiting, then ready
