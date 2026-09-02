---
name: git-commit
description: Stage files and create a conventional commit. Analyzes the diff, detects the ticket ID from the branch name, and generates a formatted commit message.
argument-hint: "<commit type override (optional)>"
---

# Git Commit

Stage changed files and commit with a conventional commit message.

## Workflow

1. Review the current state:
   ```bash
   git status
   git diff           # unstaged changes
   ```
   If anything is already staged, also run `git diff --staged`. Otherwise skip it (empty until step 3).
2. Use `AskUserQuestion` to confirm:
   - Which files to stage (or all modified)
   - Ticket ID (or detect from a branch name like `PROJ-1234`)
   - Type override if not obvious from the diff (fix/feat/refactor/etc.)
3. Stage specific files. Prefer explicit files over `git add -A`.
4. Analyze the staged diff (`git diff --staged`) and generate the commit message.
5. Show the message to the user, then commit.

## Commit Message Format

Read `~/.claude/guides/asd-ste100.md` and write the subject and the body to those rules.

```
type(scope): description, TICKET-ID

[Optional body explaining why]
```

- First line under 72 characters
- Ticket ID after a comma at the end: `fix(auth): handle timeout, PROJ-1234`. Omit it if no ticket exists yet.
- Body is optional. Use it for non-obvious changes to explain why, not what.
- No signature, attribution or `Co-Authored-By` trailer

## Types & Examples

| Type | Example |
|------|---------|
| `fix` | `fix(auth): handle session expiry race condition, PROJ-1234` |
| `feat` | `feat(api.users): add email verification, PROJ-1234` |
| `refactor` | `refactor(billing): simplify subscription state machine, PROJ-5678` |
| `docs` | `docs(readme): update deployment instructions` |
| `test` | `test(auth): add token expiry edge case tests, PROJ-1234` |
| `chore` | `chore(deps): update framework dependencies to v10, PROJ-9999` |
| `revert` | `revert(auth): revert session cookie domain change, PROJ-8784` |

`refactor` means no behavior change. Everything else is standard conventional-commit.

## Scope

Derive the scope from the directory structure of the changed files. Use the most specific meaningful directory name. Read the project's `CLAUDE.md` for module naming conventions if available.

- Use the module or feature area name: `auth`, `billing`, `api.users`
- For changes across areas, use the most significant scope or a general one
- Keep the scope short and recognizable
