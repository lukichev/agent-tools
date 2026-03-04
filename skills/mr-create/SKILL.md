---
name: mr-create
description: Create a GitLab merge request for the current branch using glab CLI. Optionally fetches Jira ticket details for the MR description.
argument-hint: "<ticket ID (optional)>"
disable-model-invocation: true
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
- If user says **yes** → generate new description content using the template, show it to the user for approval, then **append** it to the existing description (do NOT replace). Use `glab mr update` to update description only — **never overwrite the title**
- **Never replace the MR description or title completely** — always append new content below the existing description, separated by a horizontal rule (`---`)

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
| `{{SUMMARY}}` | 1-2 sentences: what was addressed |
| `{{DETAILS}}` | Explain the changes and why |
| `{{TESTING}}` | How the changes were verified |

## Rules

- MR title must match the commit message format (from `/git-commit`)
- Always show MR description to user before creating
- Target branch is `main` unless user specifies otherwise
- Always set `--remove-source-branch`
- **Never replace an existing MR's title**
- **Never replace an existing MR's description** — only append below a `---` separator
- Only update an existing MR's description when the user explicitly asks for it

## glab Reference

```bash
# Create MR
glab mr create --title "..." --description "..." --target-branch main --remove-source-branch

# Check if MR exists for current branch
glab mr list --source-branch "$(git branch --show-current)"

# View existing MR (to read current description before appending)
glab mr view <MR-NUMBER> --output json

# Update existing MR description (append only — never replace)
# 1. Read existing description first
# 2. Append new content below a --- separator
glab mr update <MR-NUMBER> --description "$(cat <<'EOF'
[existing description]

---

[new content]
EOF
)"

# View MR
glab mr view <MR-NUMBER>
```
