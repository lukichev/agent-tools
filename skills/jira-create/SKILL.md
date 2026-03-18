---
name: jira-create
description: Create a Jira ticket with standard format (title, Summary, AC, Dev Notes). Shows draft for approval before creating. Use when the user wants to file a bug, create a story, log a task, or track work in Jira — even if they don't say "Jira" explicitly.
argument-hint: "<domain and feature area>"
disable-model-invocation: true
---

# Jira Create

Create Jira tickets following the standard format.

## Workflow

1. Use `AskUserQuestion` to gather:
   - Domain and feature area (for title)
   - Brief description of the issue/feature
   - Any related tickets or error tracking issues
2. Draft the ticket content and show to user
3. After approval, create via Atlassian MCP
4. Return the new ticket ID

## Title Format

```
[Domain - Feature Area] Brief Title
```

Derive domain and feature area from the project's module/service structure. Read `CLAUDE.md` for terminology and module names.

**Examples:**
- `[Backend - Auth] Fix expired session handling`
- `[Frontend - Dashboard] Add notification indicator`
- `[API - Billing] Handle subscription downgrade edge case`
- `[Worker - Email] Fix retry logic for transient failures`
- `[Infra - CI] Update deployment pipeline for staging`

## Description Format

Use the template from `ticket-template.md` in this skill folder as the base (Summary + AC). Then add conditional sections based on ticket type:

| Placeholder | Replace with |
|-------------|--------------|
| `{{SUMMARY}}` | 1-2 sentences explaining the fix/change |
| `{{AC_ITEM_N}}` | Acceptance criterion |
| `{{AC_DETAIL}}` | Sub-detail if needed |

### Conditional Sections

Add these sections **after AC** only when relevant:

**Steps to Reproduce** — Include for Bug tickets when reproduction steps are known:
```
## Steps to Reproduce

1. Step one
2. Step two
3. Observe the issue
```

**Dev Notes** — Include only when the root cause and solution are already known (typically developer-authored bug fixes). Omit for stories, tasks, and bugs where the cause is unknown:
```
## Dev Notes

Root cause: why the bug exists

Solution: brief description of the fix
```

If an error tracking ID is available (e.g., Sentry issue), mention it in Dev Notes.

## QA Section (Optional)

For UI/frontend changes, add a **QA — Affected Pages** section listing all pages that need visual testing. Include route paths and what to verify on each page. Add this section when user requests it or when changes touch multiple UI pages.

## Important

- Always show full ticket text to user before creating
- Wait for explicit approval
- Return the created ticket ID (e.g., PROJ-1234)
- If an MR already exists for the changes, append the new ticket ID to the MR description (never replace the title or description — see `/mr-create` rules)

## Related Skills

- Use `/atlassian-research` to research an existing ticket before creating a new one
- Use `/git-commit` to stage and commit with the new ticket ID
- Use `/git-publish` to commit, push, and create MR in one flow
