---
name: mr-comment
description: Post numbered review suggestions as inline diff comments on a GitLab MR. Use after /mr-review.
argument-hint: "<MR number> <comment numbers, e.g. 1,3,5 or all>"
disable-model-invocation: true
---

# MR Comment

Post review suggestions as inline diff threads on a GitLab merge request. Designed to be used after `/mr-review` has produced numbered suggestions.

Read `~/.claude/guides/glab-api.md` before you call `glab`.

## Prerequisites

- `glab` CLI installed and authenticated
- A prior `/mr-review` with numbered suggestions in the conversation

## Workflow

### 1. Parse Input

- **MR number** — required
- **Comment selection** — which suggestions to post: specific numbers (e.g. `1, 3, 5`), a category (e.g. `security ones`), or `all`

### 2. Get Diff Refs

Reuse the `diff_refs` from a `/mr-review` in this conversation. Fetch them only when they are absent:

```bash
glab api "projects/:fullpath/merge_requests/<MR_IID>" | jq '.diff_refs'
```

### 3. Get Git Token

```bash
# Extract GitLab host from remote
git remote get-url origin

# Token is stored in glab config
glab auth status -t 2>&1 | grep "Token:"
```

### 4. Write the Comment Text

Write every comment body in ASD-STE100. See [Comment Style](#comment-style).

### 5. Post Each Comment

Use `curl` with the GitLab Discussions API. **Do NOT use `glab api -f`** — the `-f` form fields don't properly nest the `position` object, resulting in general MR comments instead of inline ones.

```bash
curl -s --request POST \
  --header "PRIVATE-TOKEN: <token>" \
  --header "Content-Type: application/json" \
  --data '{
    "body": "Comment text here (supports markdown)",
    "position": {
      "base_sha": "<from diff_refs.base_sha>",
      "start_sha": "<from diff_refs.start_sha>",
      "head_sha": "<from diff_refs.head_sha>",
      "position_type": "text",
      "old_path": "<file path>",
      "new_path": "<file path>",
      "old_line": null,
      "new_line": <line number in new file>
    }
  }' \
  "https://<gitlab-host>/api/v4/projects/<URL-encoded-project>/merge_requests/<MR_IID>/discussions"
```

### 6. Verify Each Post

After each `curl` call, check the response:
- `notes[0].type` should be `"DiffNote"` — this confirms an inline comment
- If `notes[0].type` is `null`, the comment was posted as a general MR comment (wrong positioning)

### 7. Confirm

After posting, summarize what was posted:

```
Posted 3 inline comments to MR !42:
  [1] src/auth/login.service.ts:42 — security
  [3] src/jobs/worker.ts:18 — performance
  [5] src/utils/parse.ts:7 — bug
```

## Comment Style

Read `~/.claude/guides/asd-ste100.md` and write every comment body to those rules. The reader is a busy engineer who wants the problem and the fix, nothing else.

### Structure

Three parts, in this order:

1. **The problem** — one sentence. What is wrong at this line.
2. **The consequence** — one sentence. What breaks as a result. Omit when the problem already states it.
3. **The fix** — one sentence, in the imperative. What to do.

Add a short code block only when the fix is hard to state in words.

### Length

- Max 40 words per comment in total, across all three parts.
- Max 3 sentences of prose, one per part.

### Example

The guide has the Bad case. This shows the three parts:

> The code uses the token before it validates the token. A malformed token reaches the client.
>
> Validate the token here, before line 47.

## Line Positioning Rules

| Scenario | `old_line` | `new_line` |
|----------|-----------|-----------|
| New file (added line) | `null` | line number in new file |
| Modified file (commenting on added line) | `null` | line number in new file |
| Modified file (commenting on removed/existing line) | line number in old file | `null` |
| Renamed file | use old path in `old_path`, new path in `new_path` | set lines as above |

- **Both `old_path` and `new_path`** must always be provided (same value for non-renamed files)

## Rules

- **Never post comments automatically** — only post what the user explicitly selected, nothing extra
- If a comment fails to post as `DiffNote`, warn the user and skip it rather than posting as a general comment
