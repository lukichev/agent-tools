---
name: mr-status-check
description: Check status of all open MRs authored by the current user. Shows pipeline status, unresolved comments, rebase needs, merge readiness, and Jira questions addressed to the user that have no reply. Use when the user says "check my MRs", "MR status", "any comments on my MRs?", "do I need to rebase?", "any questions for me?", "anything waiting on me?", or "what needs attention?".
context: fork
---

# MR Status Check

Dashboard of your open MRs: comments, pipeline, rebase status, merge readiness, and Jira questions that wait for your reply. Read-only. Never modify an MR, push, rebase, or post to Jira.

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

### 3. Fetch Jira questions per MR

Find the questions that wait for your reply. A question you asked that has no answer from others is not in scope.

**Ticket key.** Take the first match of `^[A-Z]+-\d+` in `source_branch`. If there is none, take the trailing `, PROJ-1234` from the title. No key: show `n/a` in the Jira column and skip this step for that MR.

**Tools.** The Jira tools are deferred. Load them once:
```
ToolSearch: select:mcp__atlassian__atlassianUserInfo,mcp__atlassian__getJiraIssue
```
Call `atlassianUserInfo` once and keep your `account_id` and display name.

**Fetch.** Issue one `getJiraIssue` call per ticket in one message, with `fields: ["summary", "status", "comment", "subtasks"]` and `responseContentFormat: "markdown"`. Then fetch every sub-task the same way, all in one message. QA posts feedback on the sub-tasks.

**Pending question rule.** On each issue (story or sub-task), sort the comments by `created`. Find the time of your last comment. A comment is a pending question when all of these hold:

1. Its author is not you.
2. It was created after your last comment on that issue, or you have no comment on that issue.
3. It mentions you (`@<your display name>`) or contains `?`.

Count the pending questions per MR across the story and its sub-tasks. Keep for each: issue key, author display name, created date, first line of the body truncated to 100 chars.

### 4. Summary table

```
| MR    | Title                          | Pipeline | Comments     | Jira       | Rebase | Behind   | Status          |
|-------|--------------------------------|----------|--------------|------------|--------|----------|-----------------|
| !123  | feat(auth): add SSO, PROJ-1234  | passed   | 2 unresolved | 1 question | needed | 34       | needs attention |
| !124  | fix(billing): prorate, PROJ-5678| running  | none         | none       | ok     | 12       | waiting         |
| !125  | refactor(deps): luxon, PROJ-9175| manual   | none         | n/a        | ok     | 0        | ready           |
```

Truncate titles to 40 chars. Sort: needs attention, then waiting, then ready.

**Status column.** Evaluate in this order and take the first match:

1. `draft`: MR is marked as draft
2. `blocked`: pipeline failed
3. `needs attention`: unresolved comments, or pending Jira questions, or conflicts, or behind > 0
4. `waiting`: pipeline running or pending
5. `ready`: pipeline passed or manual, no unresolved comments, no pending Jira questions, no rebase needed, behind == 0

A branch behind its target is not mergeable until it is rebased.

### 5. Unresolved comment detail

For each MR with unresolved comments, first line of each comment, truncated to 100 chars:

```
!123 - 2 unresolved comments:
  - @reviewer (line 42 of src/auth.ts): "Should this handle the refresh token case?"
  - @reviewer (line 88 of src/auth.ts): "Missing null check"
```

### 6. Pending question detail

For each MR with pending Jira questions, one line per question:

```
!123 - PROJ-1234 - 1 pending question:
  - Reviewer Name on PROJ-1240 (2026-09-01): "Will new trial accounts also get this?"
```

Name the issue the comment sits on, so a sub-task question is not mistaken for a story question.

## Output Format

This skill runs forked. Only the final message reaches the caller, so it must hold both:

1. The summary table, the unresolved comment detail, and the pending question detail.
2. A fenced JSON block with one record per MR, for callers such as `/git-rebase-all`:

```json
[
  {
    "iid": 123,
    "title": "feat(auth): add SSO, PROJ-1234",
    "source_branch": "PROJ-1234",
    "target_branch": "main",
    "ticket": "PROJ-1234",
    "pipeline": "success",
    "unresolved_comments": 2,
    "pending_questions": 1,
    "has_conflicts": false,
    "detailed_merge_status": "need_rebase",
    "behind": 34,
    "status": "needs attention",
    "web_url": "https://gitlab.example.com/group/project/-/merge_requests/123"
  }
]
```

`ticket` is `null` and `pending_questions` is `0` when no key was found.

Include every open MR in the JSON, `ready` ones too. `/git-rebase-all` needs the full list to resolve stacked-MR parents.
