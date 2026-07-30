---
name: mr-create
description: Create a GitLab merge request for the current branch using glab CLI. Optionally fetches Jira ticket details for the MR description.
argument-hint: "<ticket ID (optional)>"
---

# MR Create

Create a GitLab merge request for the current branch.

## Prerequisites

- `glab` CLI installed and authenticated (`brew install glab && glab auth login`)

## Workflow

### 1. Check for Existing MR

Before creating, check if an MR already exists for the current branch:
```bash
glab mr list --source-branch "$(git branch --show-current)"
```

**If MR exists:**
- Print the existing MR URL and title
- Ask the user: "MR already exists. Do you want to update its description?"
- If user says **no** → stop, do nothing further
- If user says **yes** → edit the existing description **in place** with `glab mr update`. **Do NOT** wholesale replace, and **do NOT** append a separate "Update after X" section below a `---` separator. Instead:
  - Read the current description first: `glab mr view <MR-NUMBER> --output json`
  - Extend specific bullets with new information that the new commits introduced
  - Rewrite bullets that are no longer factually accurate (e.g. a method name was renamed or removed)
  - Leave untouched anything still correct, preserving the original wording
  - Show the merged result to the user for approval before pushing
- **Never overwrite the title** with `glab mr update`
- **Exception** — wholesale rewrite is acceptable when the MR is single-commit and was just force-pushed/amended (no review history to preserve). In that case, write a clean fresh description.

### 2. Create New MR (only if no existing MR)

1. Gather information via `AskUserQuestion`:
   - **Ticket ID** (detect from branch name, or ask) — optional
   - **Testing details** for MR description
2. If ticket ID provided and Atlassian MCP is configured, fetch Jira ticket details:
   - Summary → MR description context
   - Description → Details section
   - Acceptance criteria → Testing verification
3. Build MR title from the latest commit message (should already follow `/git-commit` format)
4. Build MR description from `mr-template.md`
5. Show MR description to user for approval
6. Create MR:
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

### 3. Post-MR Slack Message

After you create a new MR, or after the user approves an update to an existing one:

1. Build a Slack-ready message in this format:
   ```
   type(scope): short description, <JIRA_BASE_URL>/browse/TICKET-ID
   <MR_URL>
   ```
   - Derive the Jira base URL from the Atlassian MCP `getAccessibleAtlassianResources` call (use the site URL), or from the target project's `CLAUDE.md` if documented there
   - Derive the MR URL from the `glab mr create` output or `glab mr view` output
2. First line: the commit message subject (without the ticket ID suffix) + Jira browse link
   - If no ticket ID is available, omit the Jira link (just the commit subject)
3. Second line: the MR URL
4. Copy the message to the clipboard:
   ```bash
   printf '%s' "<message>" | pbcopy
   ```
5. Display the copied message in the output so the user can see what was copied

## MR Description Template

Use the template from `mr-template.md` in this skill folder:

| Placeholder | Replace with |
|-------------|--------------|
| `{{TICKET_ID}}` | Ticket ID (e.g., PROJ-1234) — omit section if no ticket |
| `{{SUMMARY}}` | One sentence: what was addressed |
| `{{DETAILS}}` | 2-4 short bullets: what changed. No narrative, no restating the ticket. Omit if summary already covers it. |
| `{{TESTING}}` | Short bullets of what the developer verified and its result. State facts ("build passed", "app launched", "endpoint returned 200"), not reasoning about why the change is safe. |

### Description Style

Read `~/.claude/guides/asd-ste100.md` and write Summary, Details and Testing to those rules. This applies to a new description and to every bullet you edit on an existing one.

Per-section limits:

| Section | Limit |
|---------|-------|
| Summary | 1 sentence, max 25 words |
| Details | 2-4 bullets, 1 sentence each, max 20 words |
| Testing | 1 line per check, max 15 words, each states an outcome |

Bad:

> This MR essentially refactors the notification handling so that we're no longer relying on the old polling mechanism, which under the hood was causing duplicate sends.

Good:

> The notification service now consumes the event queue, so duplicate sends stop.

## Rules

- MR title must match the commit message format (from `/git-commit`)
- Target branch is `main` unless user specifies otherwise
- Always set `--remove-source-branch`
- Only update an existing MR's description when the user explicitly asks for it
- **Never use checkboxes** (`- [ ]`) in the Testing section — use plain bullet points instead
- **Write the description in ASD-STE100.** See [Description Style](#description-style)
- **Testing states outcomes, not reasoning.** Write what was verified and its result ("build succeeded", "endpoint returned 200"). Never explain why the change is safe — that belongs in Details.
- Omit any section with nothing meaningful to add.
