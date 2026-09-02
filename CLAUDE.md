# agent-tools

Reusable toolkit of Claude Code agents, skills and guides. Symlinked into any project's `.claude/` folder, and globally into `~/.claude/`.

## Structure

- `agents/` — 6 agents (code-reviewer, logic-reviewer, session-reflector, atlassian-researcher, escalation-researcher, claude-optimiser)
- `skills/` — 20 skills, `git-` prefix for git, `mr-` prefix for merge requests
- `guides/` — code style guides (Angular 21, NestJS, Python 3.10+, Flutter/Dart), the ASD-STE100 writing guide, and the `glab` API guide. Read on demand via a pointer line, never `@import` — an import loads the full guide every session
- `output-styles/asd-ste100.md` — a relative symlink to `guides/asd-ste100.md`, so the output style and the reference cannot drift

## Writing style

A skill or agent that produces an artifact published outside the session — a commit, an MR, a ticket, a comment, an agent report — points at `~/.claude/guides/asd-ste100.md` and must not restate the rules. It may add limits specific to its artifact, such as a word cap. A skill that only runs commands or edits code needs no pointer.

Each agent carries its own pointer line even though a subagent does load `~/.claude/CLAUDE.md`. Two reasons: a subagent does not inherit the session output style, and this repo ships `agents/` but not the user's global `CLAUDE.md`.

## Rules

- **All skills and agents must be project-agnostic.** No hard-coded project names, repo paths, team conventions or domain logic. Read the target project's `CLAUDE.md` for that at runtime.
- Skills that delegate to agents stay thin, under 15 lines of body.
- Agent description examples use one verb: "I'll use the [agent] agent to...".
- VCS is GitLab (`glab` CLI).
