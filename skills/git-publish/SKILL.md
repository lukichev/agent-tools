---
name: git-publish
description: End-to-end publish flow — commit, push, and create GitLab MR in one command. Orchestrates /git-commit, /git-push, and /mr-create skills.
argument-hint: "<commit type (optional)>"
---

# Publish

Orchestrates the full publish flow: commit changes → push to remote → create merge request.

Delegates to `/git-commit`, `/git-push`, and `/mr-create` for each step — do not duplicate their instructions here.

## Workflow

### 1. Gather Context

Use `AskUserQuestion` to collect upfront (passed to child skills):
- **Ticket ID** (detect from branch name, or ask) — optional
- **Commit type** if not obvious (fix/feat/refactor/etc.)
- **Testing details** for MR description

### 2. Commit (`/git-commit`)

Stage files and create a conventional commit. See `/git-commit` for format rules.

### 3. Push (`/git-push`)

Push the branch to remote. Creates a feature branch from main if needed. See `/git-push` for rules.

### 4. Create MR (`/mr-create`)

Create a GitLab merge request with description. Optionally fetches Jira ticket details. See `/mr-create` for template and rules.

## Example Flow

```
User: /git-publish

Agent: Let me check your changes...
       [Shows git status / diff summary]

       Questions:
       - Ticket ID? (detected PROJ-1234 from branch name)
       - Type? (looks like a fix based on the diff)
       - Testing details?

User: Yes to ticket, it's a fix, tested manually in staging

Agent: Staging files...
       Committing: fix(auth): handle session expiry race condition, PROJ-1234
       Pushing to origin/PROJ-1234...
       Creating MR...

       MR created: https://gitlab.com/your-org/your-project/-/merge_requests/123
       Title: fix(auth): handle session expiry race condition, PROJ-1234
```
