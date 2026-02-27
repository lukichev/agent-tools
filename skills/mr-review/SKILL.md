---
name: mr-review
description: Load a GitLab MR by number and display all comments, discussions, and code review feedback.
argument-hint: "<MR number>"
tools: Bash, Read, Grep, Glob
---

# MR Review

Fetch a GitLab merge request, display all comments/discussions, and provide code review feedback.

## Prerequisites

- `glab` CLI installed and authenticated (`brew install glab && glab auth login`)

## Workflow

1. Parse MR number from input
2. Fetch MR details (title, description, status)
3. Fetch all discussions and comments
4. Fetch the actual diff
5. Display existing feedback organized by type
6. Analyze changes and provide review suggestions

## Commands

### Get MR Overview

```bash
# Basic MR info with comments
glab mr view <MR_NUMBER> --comments

# MR info as JSON
glab mr view <MR_NUMBER> --output json
```

### Get Discussions (Code Comments)

```bash
# All discussions including code review comments
glab api projects/:fullpath/merge_requests/<MR_NUMBER>/discussions
```

### Get MR Diff

```bash
# View the actual changes
glab mr diff <MR_NUMBER>
```

## Output Format

### Part 1: MR Summary

```markdown
## MR #<NUMBER>: <TITLE>

**Status**: <open/merged/closed>
**Author**: <author>
**Branch**: <source> → <target>
**Files changed**: <count>

### Description
<MR description>
```

### Part 2: Existing Comments

```markdown
### Existing Review Comments

#### <file_path>:<line_number>
**By <author>** (<date>) - <✅ Resolved / ⚠️ Unresolved>

> <quoted code context>

<comment body>

---
```

### Part 3: Review Suggestions

After showing existing comments, analyze the diff and provide suggestions:

```markdown
### Review Suggestions

#### 🔍 Code Quality

**<file_path>:<line_number>**
<suggestion with explanation>

#### 🔒 Security

**<file_path>:<line_number>**
<potential security concern>

#### ⚡ Performance

**<file_path>:<line_number>**
<performance consideration>

#### 🧪 Testing

<suggestions for test coverage>

#### 📝 General

<overall observations>
```

## Grounding Findings in Context

Never report findings based solely on the diff — always verify against actual source code.

### 1. Detect context mode

```bash
# Get MR source branch
glab mr view <MR_NUMBER> --output json | python3 -c "import json,sys; mr=json.load(sys.stdin); print(mr['source_branch'])"

# Check current branch
git branch --show-current
```

- **Same branch** (source branch == current branch): you have the full codebase at the MR's state
- **Different branch**: you're reviewing someone else's work from outside

### 2. Read changed files for context

```bash
glab mr diff <MR_NUMBER> --name-only
```

**Same branch** — read the current source files directly with the Read tool. For each finding, check the surrounding code: the full function, imports, related files, and tests. A diff line that looks wrong may make perfect sense in full context.

**Different branch** — read the old (target branch) version of changed files to understand what the code looked like before:

```bash
# Read old version of a file (from target branch, usually main)
git show main:<file_path>
```

This tells you whether the change introduces a problem or fixes one, and whether "suspicious" code was already there before.

### 3. Verify before reporting

For every potential finding:
- Read the full file (or old version) to confirm the issue is real
- Check if surrounding code already handles the concern
- Look for related tests that cover the case
- Drop the finding if context proves it's a false positive

## Posting Inline Comments to MR

To post review comments as inline diff threads (appearing next to specific lines in the MR diff), use `curl` with the GitLab Discussions API. **Do NOT use `glab api -f` for this** — the `-f` form fields don't properly nest the `position` object, resulting in general MR comments instead of inline ones.

### Get MR diff refs first

```bash
glab api "projects/<URL-encoded-project>/merge_requests/<MR_IID>" | python3 -c "
import json, sys
mr = json.load(sys.stdin)
print(json.dumps(mr['diff_refs'], indent=2))
"
```

### Post inline comment via curl

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
  "https://gitlab.com/api/v4/projects/<URL-encoded-project>/merge_requests/<MR_IID>/discussions"
```

### Key rules

- **New files**: set `old_line: null`, only set `new_line`
- **Modified files (commenting on added line)**: set `old_line: null`, set `new_line` to the line in the new version
- **Modified files (commenting on existing/removed line)**: set `old_line` to line in old version, `new_line: null`
- **Both old_path and new_path** must always be provided (same value for non-renamed files)
- The response `notes[0].type` should be `"DiffNote"` — if it's `null`, the comment was posted as a general comment (wrong)
- Get the git token from the remote URL: `git remote get-url origin`

## Posting Comments

**Never post comments to the MR automatically.** After presenting the review:

1. Number each suggestion (e.g., `[1]`, `[2]`, `[3]`)
2. Wait for the user to tell you which ones to post (e.g., "post 1, 3, 5" or "post all" or "post the security ones")
3. Only post the comments the user explicitly selected — nothing else
4. After posting, confirm which comments were posted with their line references

If the user doesn't ask to post anything, don't post anything. The review output alone is valuable.

## Important

- Always show existing comments first (respect prior feedback)
- Provide actionable suggestions with specific line numbers
- Reference existing patterns in codebase
- Don't nitpick style if not project standard
- Focus on correctness, security, and maintainability
