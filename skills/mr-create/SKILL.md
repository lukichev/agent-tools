---
name: mr-create
description: Create a GitLab merge request for the current branch using glab CLI. Optionally fetches Jira ticket details for the MR description.
argument-hint: "<ticket ID (optional)>"
---

# Create MR

Create a GitLab merge request for the current branch.

## Prerequisites

- `glab` CLI installed and authenticated (`brew install glab && glab auth login`)

## Workflow

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
| `{{SUMMARY}}` | 1-2 sentences: what was addressed |
| `{{DETAILS}}` | Explain the changes and why |
| `{{TESTING}}` | How the changes were verified |

## Rules

- MR title must match the commit message format (from `/git-commit`)
- Always show MR description to user before creating
- Target branch is `main` unless user specifies otherwise
- Always set `--remove-source-branch`

## glab Reference

```bash
# Create MR
glab mr create --title "..." --description "..." --target-branch main

# Update existing MR
glab mr update <MR-NUMBER> --title "..." --description "..."

# List MRs for branch
glab mr list --source-branch TICKET-ID

# View MR
glab mr view <MR-NUMBER>
```
