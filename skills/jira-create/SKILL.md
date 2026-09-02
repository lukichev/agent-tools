---
name: jira-create
description: Create a Jira ticket with standard format (title, Summary, AC, Dev Notes). Shows the draft for approval before creating. Use when the user wants to file a bug, create a story, log a task, or track work in Jira, even if they don't say "Jira" explicitly.
argument-hint: "<domain and feature area>"
disable-model-invocation: true
---

# Jira Create

## Workflow

1. Use `AskUserQuestion` to gather:
   - Domain and feature area (for the title)
   - Description of the issue or feature
   - Related tickets or error tracking issues
2. Draft the ticket and show it to the user
3. After approval, create it via Atlassian MCP
4. Return the new ticket ID

## Title Format

```
[Domain - Feature Area] Brief Title
```

Derive domain and feature area from the project's module structure. Read `CLAUDE.md` for terminology and module names.

Examples:
- `[Backend - Auth] Fix expired session handling`
- `[Frontend - Dashboard] Add notification indicator`
- `[API - Billing] Handle subscription downgrade edge case`
- `[Worker - Email] Fix retry logic for transient failures`
- `[Infra - CI] Update deployment pipeline for staging`

## Description Format

Start from `ticket-template.md` in this skill folder (Summary + AC):

| Placeholder | Replace with |
|-------------|--------------|
| `{{SUMMARY}}` | 1-2 sentences explaining the fix or change |
| `{{AC_ITEM_N}}` | Acceptance criterion |
| `{{AC_DETAIL}}` | Sub-detail if needed |

### Conditional Sections

Add after the AC, only when relevant.

**Steps to Reproduce** - for a Bug when the steps are known:
```
## Steps to Reproduce

1. Step one
2. Step two
3. Observe the issue
```

**Dev Notes** - only when the root cause and solution are known. Omit for stories, tasks, and bugs with an unknown cause:
```
## Dev Notes

Root cause: why the bug exists

Solution: brief description of the fix
```

Mention an error tracking ID (a Sentry issue, for example) in Dev Notes when one exists.

**QA - Affected Pages** - for UI changes, when the user asks or the change touches several pages. List each page with its route and what to verify.

## Ticket Style

Read `~/.claude/guides/asd-ste100.md` and write the title, Summary, AC, Steps to Reproduce, Dev Notes and QA to those rules. The reader is a developer who picks the ticket up cold, weeks later.

| Section | Shape |
|---------|-------|
| Title | Short, after the `[Domain - Feature Area]` prefix |
| Summary | 1-2 sentences |
| AC item | 1-2 sentences, one observable behavior |
| Steps | One imperative action per step |
| Dev Notes | One sentence for the root cause, one for the solution |

Each AC is testable on its own and describes one observable behavior. "X works like before" and "No regressions" are not AC.

Write each AC in the present tense, as a statement of the finished behavior: "The export button downloads a CSV file." Not a task ("Add a download button"), not a wish ("Users should be able to export").

Bad:

> The system should ideally be able to handle the situation where a user might have multiple active sessions, without breaking anything.

Good:

> A user with two active sessions signs out of one session. The other session stays active.

If an MR already exists for the change, append the new ticket ID to its description per `/mr-create`.

## Related Skills

- `/atlassian-research` - research an existing ticket before creating a new one
- `/git-commit` - commit with the new ticket ID
- `/git-publish` - commit, push, and create the MR
