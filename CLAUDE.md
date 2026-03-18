# agent-tools

Reusable toolkit of Claude Code agents, skills, and code style guides. Designed to be symlinked into any project's `.claude/` folder.

## Structure

- `agents/` — 7 agents (code-reviewer, logic-review, session-reflector, atlassian-researcher, domain-reviewer, escalation-researcher, claude-optimiser)
- `skills/` — 17 skills (git-commit, git-push, git-publish, git-rebase, git-rebase-all, git-start, mr-create, mr-review, mr-comment, mr-status-check, ready-check, reflect, jira-create, atlassian-research, escalation-research, postman-export, skill-create)
- `guides/` — Code style guides (Angular 19, Python 3.10+, NestJS) imported via `@guides/<name>.md`

## Rules

- **All skills and agents must be project-agnostic.** They must not hard-code project names, repo paths, team conventions, or domain-specific logic. Any project-specific context must be read from the target project's `CLAUDE.md` at runtime.

## Conventions

- Agents and skills are project-agnostic — they read the target project's `CLAUDE.md` for context
- Skills that delegate to agents should be thin (< 15 lines of body)
- Agent description examples use consistent verb: "I'll use the [agent] agent to..."
- Git skills use `git-` prefix; MR skills use `mr-` prefix
- VCS: GitLab (`glab` CLI)
