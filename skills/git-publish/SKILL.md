---
name: git-publish
description: End-to-end publish flow — commit, push, and create GitLab MR in one command. Orchestrates /git-commit, /git-push, and /mr-create skills.
argument-hint: "<commit type (optional)>"
disable-model-invocation: true
---

# Git Publish

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

### 4. Create or Update MR (`/mr-create`)

Check if an MR already exists for the current branch. If it does, skip MR creation — only offer to update the MR description if the user explicitly requests it. See `/mr-create` for rules.

## Example Flows

### New MR
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

### Existing MR
```
User: /git-publish

Agent: Staging files...
       Committing: fix(auth): add retry logic for token refresh, PROJ-1234
       Pushing to origin/PROJ-1234...

       MR !123 already exists for this branch:
       "fix(auth): handle session expiry race condition, PROJ-1234"
       https://gitlab.com/your-org/your-project/-/merge_requests/123

       Do you want to update the MR description?

User: No

Agent: Done. Changes pushed to origin/PROJ-1234.
```
