---
name: git-start
description: Start work on a new feature or ticket by creating a branch from the latest main. Takes a Jira ticket number (e.g. DOC-1020) or a feature name as the argument. Fetches and updates main before branching. If a Jira ticket number is provided, researches the ticket and enters plan mode. Use when the user says "start on DOC-1020", "let's work on ticket X", "create a branch for...", "begin feature Y", or "start a new branch".
argument-hint: "<TICKET-123 or feature-name>"
disable-model-invocation: true
---

# git-start

Set up a branch and context for new feature work.

## Steps

### 1. Parse the argument

`$ARGUMENTS` is either:
- A **Jira ticket number** — matches the pattern `[A-Z]+-\d+` (e.g. `DOC-1020`, `PROJ-42`)
- A **feature name** — free text (e.g. `user authentication`, `fix login redirect`)

If it's a feature name, slugify it: lowercase, spaces and special characters replaced with hyphens.

### 2. Determine base branch

Default base branch is `main`. Use a different base only if the user explicitly named one (e.g. "branch from develop").

### 3. Update the base branch

```
git fetch origin
git checkout <base-branch>
git pull origin <base-branch>
```

### 4. Create and check out the new branch

```
git checkout -b <branch-name>
```

Branch name is the Jira ticket number (e.g. `DOC-1020`) or the slugified feature name.

**Worktree variant** — if the user asks to work in a worktree (e.g. "in a worktree", "isolated"), skip step 3/4 and use `EnterWorktree` with `<branch-name>` instead. The tool creates `worktree-<branch-name>`; immediately rename it to drop the prefix:

```
git branch -m worktree-<branch-name> <branch-name>
```

### 5. If Jira ticket — research and plan

If the argument was a Jira ticket number:
1. Use the `atlassian-research` skill to fetch ticket details for `$ARGUMENTS`
2. After research completes, enter plan mode to outline the implementation approach based on the ticket

If the argument was a feature name, skip this step — just confirm the branch was created.

## Output

Confirm the branch name and base branch used. If ticket research ran, summarize what was found before entering plan mode.
