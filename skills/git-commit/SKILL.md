---
name: git-commit
description: Stage files and create a conventional commit. Analyzes the diff, detects ticket ID from branch name, and generates a properly formatted commit message.
argument-hint: "<commit type override (optional)>"
---

# Commit

Stage changed files and create a commit with a conventional commit message.

## Workflow

1. Review current state:
   ```bash
   git status
   git diff
   git diff --staged
   ```
2. Use `AskUserQuestion` to confirm:
   - Which files to stage (or confirm all modified)
   - Ticket ID (or detect from branch name like `PROJ-1234`)
   - Type override if not obvious from the diff (fix/feat/refactor/etc.)
3. Stage specific files (prefer explicit files over `git add -A`)
4. Analyze the staged diff and generate commit message
5. Show the message to the user, then commit

## Commit Message Format

```
type(scope): description, TICKET-ID

[Optional body explaining why]
```

**Rules:**
- First line under 72 characters
- Ticket ID after a comma at the end (e.g., `fix(auth): handle timeout, PROJ-1234`)
- Include ticket ID when available; omit if no ticket exists yet
- Body is optional but helpful for non-obvious changes — explains "why", not "what"
- No signature block
- NEVER add "Co-Authored-By" lines

## Types & Examples

| Type | When to use | Example |
|------|-------------|---------|
| `fix` | Bug fixes | `fix(auth): handle session expiry race condition, PROJ-1234` |
| `feat` | New features | `feat(api.users): add email verification, PROJ-1234` |
| `refactor` | Code restructuring without behavior change | `refactor(billing): simplify subscription state machine, PROJ-5678` |
| `docs` | Documentation only | `docs(readme): update deployment instructions` |
| `test` | Adding/updating tests | `test(auth): add token expiry edge case tests, PROJ-1234` |
| `chore` | Maintenance, dependencies, configs | `chore(deps): update framework dependencies to v10, PROJ-9999` |
| `revert` | Reverting previous changes | `revert(auth): revert session cookie domain change, PROJ-8784` |

## Scope

Derive scope from the directory structure of changed files. Use the most specific meaningful directory name. Read the project's `CLAUDE.md` for module naming conventions if available.

- Use the module or feature area name (e.g., `auth`, `billing`, `api.users`)
- For changes spanning multiple areas, use the most significant scope or a general one
- Keep scope short and recognizable
