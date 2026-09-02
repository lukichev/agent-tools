---
name: git-start
description: Start work on a new feature or ticket by creating a branch. Takes a Jira ticket (e.g. PROJ-1020) or a feature name. Defaults to branching from main. Supports stacking via "onto <parent>"; if no "onto" is given but the current branch looks like a ticket, asks before defaulting to main. If a Jira ticket is provided, researches it and enters plan mode. Use when the user says "start on PROJ-1020", "create a branch for...", "begin feature Y".
argument-hint: "<TICKET-123 or feature-name> [onto <PARENT-TICKET>]"
disable-model-invocation: true
---

# git-start

Set up a branch and context for new work.

## Steps

### 1. Parse the argument

Strip a trailing `onto <parent>` / `on <parent>` and keep `<parent>` as the **explicit base**. The remainder is a Jira ticket (`[A-Z]+-\d+`) or a feature name (slugify: lowercase, hyphenate).

### 2. Determine the base branch

1. **Explicit `onto <parent>`**: base = `<parent>`.
2. **No explicit base, current branch matches `[A-Z]+-\d+`**: `AskUserQuestion`, stack on the current branch or branch from main.
3. **Otherwise**: base = `main`.

Tell the user which base was chosen.

### 3. Update the base branch

```bash
git fetch origin <base>
git checkout <base>
git pull --ff-only origin <base>
```

If `--ff-only` fails (a parent ticket branch was rebased upstream), stop and ask. Do not `reset --hard`, local commits may be unpushed work.

### 4. Create the branch

```bash
git checkout -b <branch-name>
```

Branch name = ticket ID or slugified feature name.

**Worktree variant**: if the user asks ("in a worktree", "isolated"), use `EnterWorktree` with `<branch-name>` based off `<base>` instead. Rename `worktree-<branch-name>` to `<branch-name>` at once.

### 5. Jira ticket: research and plan

1. Run `atlassian-research` for the ticket ID.
2. **Confluence links.** Collect every Confluence page the ticket references: remote links, smart links in the description, and any `/wiki/spaces/` URL in the description or the comments. Include pages linked from an epic or a parent ticket. List them by title with `AskUserQuestion`, `multiSelect: true`, and ask which to read. Read the chosen pages before you plan. Never read one without asking, and never skip the question when a link exists.
3. Enter plan mode.
4. If the base is a parent ticket branch, note in the briefing that the MR must target `<parent>`, not `main`.

For a feature name, skip this step and confirm the branch.

## Output

Confirm the branch name, the base, and how the base was chosen (explicit `onto`, stack prompt, or default).
