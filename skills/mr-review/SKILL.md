---
name: mr-review
description: Load a GitLab MR by number and display all comments, discussions, and code review feedback. Use when the user wants to review an MR, check MR comments, see review feedback, or says "review MR !123".
argument-hint: "<MR number>"
---

# MR Review

Fetch a GitLab merge request, display all existing comments/discussions, then delegate diff analysis to the `code-reviewer` agent.

## Prerequisites

- `glab` CLI installed and authenticated (`brew install glab && glab auth login`)

## Workflow

1. Parse MR number from `$ARGUMENTS`
2. Fetch MR details and discussions:
   ```bash
   glab mr view <MR_NUMBER> --output json
   glab api projects/:fullpath/merge_requests/<MR_NUMBER>/discussions
   ```
3. Display the MR summary and existing comments (formats below)
4. Launch the `code-reviewer` agent for review suggestions (see Delegation)
5. Number the agent's findings and offer to post via `/mr-comment`

## Delegation to code-reviewer

All diff analysis happens in the `code-reviewer` agent — do not review the diff inline in the main context. Launch it with a self-contained prompt that includes:

- MR number, source branch, target branch
- **Context mode** — compare `git branch --show-current` to the MR's `source_branch`:
  - **Same branch**: the working tree matches the MR state — read source files directly
  - **Different branch**: the working tree does NOT match the MR state — work from the diff, and read old versions via `git show <target_branch>:<file_path>` to understand what the code looked like before
- Unresolved existing comments (one line each), so it doesn't repeat feedback already given
- Instructions for the agent:
  - Fetch the diff itself: `glab mr diff <MR_NUMBER>` (and `--name-only` for the file list)
  - Never report findings based solely on the diff — verify against actual source; check whether surrounding code or tests already handle the concern, and drop false positives
  - Return findings as a numbered list, each with `file:line`, a category (bug / security / performance / testing / style), and a concise actionable suggestion

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
**By <author>** (<date>) — <Resolved | Unresolved>

> <quoted code context>

<comment body>

---
```

### Part 3: Review Suggestions

Render the code-reviewer agent's findings as numbered suggestions:

```markdown
### Review Suggestions

**[1] <file_path>:<line_number>** — <category>
<suggestion with explanation>
```

## Posting Comments

Suggestions are numbered (`[1]`, `[2]`, `[3]`). If the user wants to post any to GitLab, use `/mr-comment`.

## Important

- Always show existing comments first (respect prior feedback)
- Don't nitpick style if not project standard
- Focus on correctness, security, and maintainability
