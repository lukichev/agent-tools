---
name: git-publish
description: End-to-end publish flow — commit, push, and create GitLab MR in one command. Orchestrates /git-commit, /git-push, and /mr-create skills.
argument-hint: "<commit type (optional)>"
disable-model-invocation: true
---

# Git Publish

Orchestrates the full publish flow: commit changes → push to remote → create merge request.

**CRITICAL:** Before each step, you MUST read the corresponding skill file and follow its instructions exactly:
- `/git-commit` → `~/.claude/skills/git-commit/SKILL.md`
- `/git-push` → `~/.claude/skills/git-push/SKILL.md`
- `/mr-create` → `~/.claude/skills/mr-create/SKILL.md`

Do not improvise or skip rules from these skills. Read each file before executing that step.

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

Give the step 1 answers to every child step. A child skips its own `AskUserQuestion` for any value it already has.

### 4. Create or Update MR (`/mr-create`)

Check if an MR already exists for the current branch. If it does, skip MR creation — only offer to update the MR description if the user explicitly requests it. See `/mr-create` for rules.
