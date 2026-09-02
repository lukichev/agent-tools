---
name: mr-comment
description: Post numbered review suggestions as inline diff comments on a GitLab MR. Use after /mr-review.
argument-hint: "<MR number> <comment numbers, e.g. 1,3,5 or all>"
disable-model-invocation: true
---

# MR Comment

Post the numbered suggestions from a `/mr-review` in this conversation as inline diff threads on a GitLab merge request. Needs `glab` authenticated.

Read `~/.claude/guides/glab-api.md` before you call `glab`.

## Workflow

### 1. Parse input

- **MR number**: required.
- **Comment selection**: specific numbers (`1, 3, 5`), a category (`security ones`), or `all`.

### 2. Get diff refs

Reuse the `diff_refs` from the `/mr-review`. Fetch them only when absent:

```bash
glab api "projects/:fullpath/merge_requests/<MR_IID>" | jq '.diff_refs'
```

### 3. Get the host and token

```bash
git remote get-url origin
glab auth status -t 2>&1 | grep "Token:"
```

### 4. Write the comment text

See [Comment Style](#comment-style).

### 5. Post each comment

Use `curl` against the Discussions API. Never `glab api -f`: its form fields do not nest the `position` object, so the comment lands as a general MR comment.

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

### 6. Verify each post

Check `notes[0].type` in the response. `"DiffNote"` is an inline comment. `null` means it posted as a general MR comment: warn the user and skip it. Never repost it as a general comment.

### 7. Confirm

```
Posted 3 inline comments to MR !42:
  [1] src/auth/login.service.ts:42 - security
  [3] src/jobs/worker.ts:18 - performance
  [5] src/utils/parse.ts:7 - bug
```

## Comment Style

Read `~/.claude/guides/asd-ste100.md` and write every comment body to those rules. The reader wants the problem and the fix, nothing else.

Three parts, in this order:

1. **The problem**: one sentence. What is wrong at this line.
2. **The consequence**: one sentence. What breaks as a result. Omit when the problem states it.
3. **The fix**: one sentence, imperative.

Add a short code block only when the fix is hard to state in words.

Example:

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

Always send both `old_path` and `new_path`, the same value for a file that was not renamed.

## Rules

- Post only what the user selected. Never post a comment on your own initiative.
