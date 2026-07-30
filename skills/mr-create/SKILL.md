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
  - Read the current description first
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

## MR Description Template

Use the template from `mr-template.md` in this skill folder:

| Placeholder | Replace with |
|-------------|--------------|
| `{{TICKET_ID}}` | Ticket ID (e.g., PROJ-1234) — omit section if no ticket |
| `{{SUMMARY}}` | One sentence: what was addressed |
| `{{DETAILS}}` | 2-4 short bullets: what changed. No narrative, no restating the ticket. Omit if summary already covers it. |
| `{{TESTING}}` | Short bullets of what the developer verified and its result. State facts ("build passed", "app launched", "endpoint returned 200"), not reasoning about why the change is safe. |

### 3. Post-MR Slack Message

After successfully creating a new MR **or** finding an existing one (skip only if the user cancels entirely):

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

## Rules

- MR title must match the commit message format (from `/git-commit`)
- Always show MR description to user before creating
- Target branch is `main` unless user specifies otherwise
- Always set `--remove-source-branch`
- **Never replace an existing MR's title**
- **After new commits land on an existing MR, edit the description in place** — extend bullets with new info, rewrite stale ones, leave the rest alone. Do NOT wholesale replace AND do NOT append below a `---` separator.
- Wholesale rewrite IS acceptable for a single-commit force-push/amend (no review history yet)
- Only update an existing MR's description when the user explicitly asks for it
- **Never use checkboxes** (`- [ ]`) in the Testing section — use plain bullet points instead
- **Testing section states outcomes, not reasoning.** Write only what was verified and its pass/fail result (e.g. "Build succeeded, app launched, faxes sent correctly"). Do not explain *why* something is safe or *why* it should work (e.g. no code-reasoning like "the method only destructures X, so the change is type-only"). That belongs in Details, not Testing.
- **Keep descriptions terse.** Summary: one sentence. Details: 2-4 short bullets max — what changed, not a narrative. Testing: short bullets of what was verified. No filler, no restating the ticket, no "this MR does X, Y, and Z" preambles. If a section has nothing meaningful to add, omit it.

## glab Reference

```bash
# Create MR
glab mr create --title "..." --description "..." --target-branch main --remove-source-branch

# Check if MR exists for current branch
glab mr list --source-branch "$(git branch --show-current)"

# View existing MR (to read current description before editing)
glab mr view <MR-NUMBER> --output json

# Update existing MR description (edit in place — never wholesale replace,
# never append below a --- separator). See rules above:
# - Extend specific bullets with new info from the new commits
# - Rewrite bullets that are no longer factually accurate
# - Leave untouched anything still correct
# - Show the merged result to the user for approval before pushing
glab mr update <MR-NUMBER> --description "$(cat <<'EOF'
[merged description — original text with targeted edits, no separator]
EOF
)"

# View MR
glab mr view <MR-NUMBER>
```
