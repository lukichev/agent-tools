---
name: mr-review
description: Load a GitLab MR by number and display all comments, discussions, and code review feedback. Use when the user wants to review an MR, check MR comments, see review feedback, or says "review MR !123".
argument-hint: "<MR number>"
disable-model-invocation: true
---

# MR Review

Fetch a GitLab merge request, display all comments/discussions, and provide code review feedback.

## Prerequisites

- `glab` CLI installed and authenticated (`brew install glab && glab auth login`)

## Workflow

1. Parse MR number from `$ARGUMENTS`
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
glab mr view <MR_NUMBER> --output json | jq -r '.source_branch'

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

## Posting Comments

After presenting the review, number each suggestion (e.g., `[1]`, `[2]`, `[3]`). If the user wants to post them to GitLab, use `/mr-comment`.

## Important

- Always show existing comments first (respect prior feedback)
- Provide actionable suggestions with specific line numbers
- Reference existing patterns in codebase
- Don't nitpick style if not project standard
- Focus on correctness, security, and maintainability
