# agent-tools

A reusable toolkit of Claude Code agents, skills, and code style guides. Project-agnostic — designed to be copied or symlinked into any project.

## Usage

Copy or symlink the directories into your project's `.claude/` folder:

```bash
# Option 1: Symlink (recommended — stays in sync)
ln -s /path/to/agent-tools/agents/ /your-project/.claude/agents
ln -s /path/to/agent-tools/skills/ /your-project/.claude/skills

# Option 2: Copy
cp -r /path/to/agent-tools/{agents,skills} /your-project/.claude/
```

For code style guides, import them from your project's `CLAUDE.md`:

```markdown
@/path/to/agent-tools/guides/angular.md

## Project-Specific
[your project-specific rules here]
```

## How It Works

Most agents and skills read the target project's `CLAUDE.md` for context. For best results, document your project's tech stack, module structure, conventions, and domain terminology in its `CLAUDE.md`.

## Agents

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| `code-reviewer` | Multi-lens code review (bugs, security, performance, architecture, style) | After writing or significantly modifying code |
| `logic-review` | Change-set logic analysis (coherence, scope, assumptions, intent) | When reviewing a PR/MR or diff for logical soundness |
| `session-reflector` | Session memory — recover context, trace decisions, flag mistakes | When context was lost to compaction or you need session retrospective |
| `atlassian-researcher` | Deep Jira/Confluence research | When researching a ticket or topic across Jira/Confluence |
| `domain-reviewer` | Domain-expert analysis of business rules, algorithms, pipelines | When auditing domain logic, calculations, or data processing correctness |
| `escalation-researcher` | Multi-phase escalation/issue investigation | When researching a complex issue ticket with historical context |
| `claude-optimiser` | Audit and optimize Claude Code config | To review CLAUDE.md, agents, skills, hooks, model selection |

## Skills

| Skill | Purpose |
|-------|---------|
| `/reflect` | Session retrospective via session-reflector agent |
| `/git-commit` | Stage files and create a conventional commit |
| `/git-push` | Push branch to remote (creates feature branch from main if needed) |
| `/git-publish` | End-to-end: orchestrates `/git-commit` → `/git-push` → `/mr-create` |
| `/git-rebase` | Rebase current branch onto main (or another target), handles squash-merged parents |
| `/ready-check` | Pre-publish gate — AC completeness, debug artifact scan, code review |
| `/mr-create` | Create GitLab MR with description (`glab`) |
| `/mr-review` | Load and review a GitLab MR with comments |
| `/mr-comment` | Post numbered review suggestions as inline diff comments on a GitLab MR |
| `/jira-create` | Create Jira tickets with standard format |
| `/atlassian-research` | Research Jira tickets/topics via atlassian-researcher agent |
| `/postman-export` | Generate Postman collection JSON from API endpoints on current branch |
| `/escalation-research` | Deep investigation of escalation/issue tickets |

## Code Style Guides

| Guide | Import with |
|-------|-------------|
| Angular 19 | `@guides/angular.md` |
| Python 3.10+ | `@guides/python.md` |

## Helpful Links

- [component.gallery](https://component.gallery/) — catalog of UI components across design systems

## Requirements

- **VCS**: GitLab (`glab` CLI)
- **Atlassian MCP**: Required for `atlassian-researcher`, `escalation-researcher`, and `jira-create`. Other tools work without it.
