---
name: mr-create
description: Create a GitLab merge request for the current branch using glab CLI. Optionally fetches Jira ticket details for the MR description.
argument-hint: "<ticket ID (optional)>"
---

# MR Create

Create a GitLab merge request for the current branch. Needs `glab` installed and authenticated (`brew install glab && glab auth login`).

## Workflow

### 1. Check for an existing MR

```bash
glab mr list --source-branch "$(git branch --show-current)"
```

**If an MR exists:**
- Print its URL and title.
- Ask: "MR already exists. Do you want to update its description?"
- **No**: stop.
- **Yes**: edit the description in place with `glab mr update`. Do not replace it, and do not append an "Update after X" section below a `---` separator:
  - Read the current description: `glab mr view <MR-NUMBER> --output json`
  - Extend bullets with what the new commits add.
  - Rewrite bullets that are no longer accurate, such as a renamed or removed method.
  - Leave correct bullets untouched, wording included.
  - Show the merged result for approval before you push it.
- Never overwrite the title with `glab mr update`.
- **Exception**: a single-commit MR that was just force-pushed or amended has no review history. Write a fresh description.

### 2. Create a new MR

1. Gather with `AskUserQuestion`:
   - **Ticket ID** (detect from the branch name, or ask). Optional.
   - **Testing details** for the description.
2. If a ticket ID exists and Atlassian MCP is configured, fetch the ticket:
   - Summary: description context
   - Description: Details section
   - Acceptance criteria: Testing verification
3. Title = the latest commit subject, which already follows the `/git-commit` format.
4. Build the description from `mr-template.md`.
5. Show the description for approval.
6. Create the MR:
   ```bash
   glab mr create \
     --title "type(scope): description, TICKET-ID" \
     --description "$(cat <<'EOF'
   [generated description]
   EOF
   )" \
     --target-branch main \
     --remove-source-branch
   ```
   Target is `main` unless the user names another branch. Always pass `--remove-source-branch`.

### 3. Slack message

After a new MR, or after the user approves an update to an existing one:

1. Build the message:
   ```
   type(scope): short description, <JIRA_BASE_URL>/browse/TICKET-ID
   <MR_URL>
   ```
   - Jira base URL: the site URL from `getAccessibleAtlassianResources`, or the project's `CLAUDE.md`.
   - MR URL: the `glab mr create` or `glab mr view` output.
2. Line 1: the commit subject without the ticket suffix, then the Jira link. No ticket: the subject alone.
3. Line 2: the MR URL.
4. Copy it: `printf '%s' "<message>" | pbcopy`
5. Print the copied message.

## MR Description Template

Use `mr-template.md` in this skill folder. Omit any section with nothing to add.

| Placeholder | Replace with |
|-------------|--------------|
| `{{TICKET_ID}}` | Ticket ID, such as PROJ-1234. Omit the section when there is no ticket. |
| `{{SUMMARY}}` | One sentence: what was addressed. |
| `{{DETAILS}}` | Short bullets, one change each. No narrative, no restating the ticket. Omit if the summary covers it. |
| `{{TESTING}}` | Short bullets: what the developer verified and its result. Plain bullets, never checkboxes (`- [ ]`). |

### Description Style

Read `~/.claude/guides/asd-ste100.md` and write Summary, Details and Testing to those rules. This applies to a new description and to every bullet you edit on an existing one.

| Section | Shape |
|---------|-------|
| Summary | One sentence |
| Details | One sentence per bullet, one change per bullet |
| Testing | One outcome per bullet. Group related checks into one bullet |

Testing states outcomes ("build succeeded", "endpoint returned 200"), never reasoning about why the change is safe. Reasoning belongs in Details.

Bad:

> This MR essentially refactors the notification handling so that we're no longer relying on the old polling mechanism, which under the hood was causing duplicate sends.

Good:

> The notification service now consumes the event queue, so duplicate sends stop.

### No quantities in Testing

Testing says what was verified, never how much. A count goes stale when anyone adds a test.

Never write:

- a test or suite count ("21 unit tests pass", "19 suites, 267 tests")
- a row, record or grant count ("1727 admin grants", "3 tables created")
- a count of enum values, columns, endpoints, files or migrations

Bad:

> - 21 guest unit tests pass.
> - Workspace regression passes: 19 suites, 267 tests.
> - Schema holds 3 guest tables, 4 share activity types, 1727 admin grants.

Good:

> - All unit tests pass, server and portal build.
> - The schema matches the entities, and the permission backfill reached the admin roles.
