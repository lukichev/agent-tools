---
name: git-publish
description: End-to-end publish flow. Commit, push, and create a GitLab MR in one command. Orchestrates /git-commit, /git-push, and /mr-create.
argument-hint: "<commit type (optional)>"
disable-model-invocation: true
---

# Git Publish

Run the full publish flow: commit, push, create merge request.

Before each step, read the skill file and follow it exactly. Do not skip its rules:
- `/git-commit` → `~/.claude/skills/git-commit/SKILL.md`
- `/git-push` → `~/.claude/skills/git-push/SKILL.md`
- `/mr-create` → `~/.claude/skills/mr-create/SKILL.md`

## Workflow

### 1. Gather Context

Use `AskUserQuestion` to collect once, for the child steps:
- **Ticket ID** (detect from the branch name, or ask). Optional.
- **Commit type** if not obvious (fix/feat/refactor/etc.)
- **Testing details** for the MR description

Give these answers to every child step. A child skips its own `AskUserQuestion` for any value it already has.

### 2. Commit (`/git-commit`)

Stage files and create a conventional commit.

### 3. Push (`/git-push`)

Push the branch to the remote. Creates a feature branch from main if needed.

### 4. Create or Update MR (`/mr-create`)

If an MR already exists for the current branch, skip creation. Offer to update the description only if the user asks for it.
