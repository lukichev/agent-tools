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

**The global symlinks are required, not optional.** Skills read each other by absolute path (`mr-review` reads `~/.claude/skills/ready-check/references/`, `git-publish` reads `~/.claude/skills/git-commit/`), and agents read guides the same way. Without these, those steps fail:

```bash
ln -s /path/to/agent-tools/skills  ~/.claude/skills
ln -s /path/to/agent-tools/agents  ~/.claude/agents
ln -s /path/to/agent-tools/guides  ~/.claude/guides
```

For code style guides, symlink them globally (agents like `code-reviewer` expect `~/.claude/guides/`):

```bash
ln -s /path/to/agent-tools/guides/ ~/.claude/guides
ln -s /path/to/agent-tools/output-styles ~/.claude/output-styles
```

Then reference them **on demand** from your project's `CLAUDE.md` — do NOT `@import` them. An `@import` loads the full guide (2–7k tokens) into every session, even ones that never touch code. A pointer line costs nothing until the guide is actually needed:

```markdown
## Code Style

Before writing or reviewing Angular code, read `~/.claude/guides/angular.md` and follow it.
```

## How It Works

Most agents and skills read the target project's `CLAUDE.md` for context. For best results, document your project's tech stack, module structure, conventions, and domain terminology in its `CLAUDE.md`.

## Agents

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| `code-reviewer` | Multi-lens code review (bugs, security, performance, architecture, style) | After writing or significantly modifying code |
| `logic-reviewer` | Logic analysis (algorithms, business rules) and change-set review (coherence, scope, assumptions, intent) | When auditing domain logic or reviewing a PR/MR for logical soundness |
| `session-reflector` | Session memory — recover context, trace decisions, flag mistakes | When context was lost to compaction or you need session retrospective |
| `atlassian-researcher` | Deep Jira/Confluence research | When researching a ticket or topic across Jira/Confluence |
| `escalation-researcher` | Multi-phase escalation/issue investigation | When researching a complex issue ticket with historical context |
| `claude-optimiser` | Audit and optimize Claude Code config | To review CLAUDE.md, agents, skills, hooks, model selection |

## Skills

### Git workflow

| Skill | Purpose |
|-------|---------|
| `/git-start` | Start a branch from latest main for a Jira ticket or feature name (optionally worktree-isolated) |
| `/git-commit` | Stage files and create a conventional commit |
| `/git-push` | Push branch to remote (creates feature branch from main if needed) |
| `/git-rebase` | Rebase current branch onto its MR target (or main), handles squash-merged parents |
| `/git-rebase-all` | Rebase all open GitLab MRs in parallel via isolated subagents |
| `/git-cleanup` | Prune merged branches, clean worktrees, and review stashes after merges (verifies before deleting) |
| `/git-publish` | End-to-end: orchestrates `/git-commit` → `/git-push` → `/mr-create` |
| `/ready-check` | Pre-publish gate — AC completeness, debug artifact scan, code review |

### GitLab merge requests

| Skill | Purpose |
|-------|---------|
| `/mr-create` | Create GitLab MR with description (`glab`) |
| `/mr-review` | Load and review a GitLab MR with comments |
| `/mr-comment` | Post numbered review suggestions as inline diff comments on a GitLab MR |
| `/mr-status-check` | Dashboard of your open MRs — pipeline, comments, rebase needs, merge readiness |

### Atlassian

| Skill | Purpose |
|-------|---------|
| `/jira-create` | Create Jira tickets with standard format |
| `/atlassian-research` | Research Jira tickets/topics via atlassian-researcher agent |
| `/escalation-research` | Deep investigation of escalation/issue tickets |

### Other

| Skill | Purpose |
|-------|---------|
| `/reflect` | Session retrospective via session-reflector agent |
| `/postman-export` | Generate Postman collection JSON from API endpoints on current branch |
| `/skill-create` | Create new skills or improve existing ones |

## Guides

Referenced on demand (see Usage) — never `@import`ed into `CLAUDE.md`.

| Guide | Path |
|-------|------|
| Angular 21 | `~/.claude/guides/angular.md` |
| NestJS | `~/.claude/guides/nestjs.md` |
| Python 3.10+ | `~/.claude/guides/python.md` |
| Flutter / Dart | `~/.claude/guides/flutter.md` |
| ASD-STE100 writing | `~/.claude/guides/asd-ste100.md` |

### ASD-STE100 writing guide

`guides/asd-ste100.md` holds the prose rules for MR descriptions, MR comments, Jira tickets, commit messages, agent reports and documentation. All 6 agents read it on demand, as do the `git-commit`, `mr-comment`, `mr-create`, `mr-review` and `jira-create` skills. Skills that only run commands or edit code do not.

The rules apply to prose these tools generate. They do not apply to the repo's own instruction files.

The same file doubles as an output style, which applies the rules to a whole session. `output-styles/asd-ste100.md` is a relative symlink to the guide, so both roles read one file. Symlink the directory:

```bash
ln -s /path/to/agent-tools/output-styles ~/.claude/output-styles
```

Then select it with `/output-style`. To apply the rules without the output style, add a pointer line to your `CLAUDE.md`.

## Helpful Links

- [component.gallery](https://component.gallery/) — catalog of UI components across design systems

## Requirements

- **VCS**: GitLab (`glab` CLI)
- **Atlassian MCP**: Required for `atlassian-researcher`, `escalation-researcher`, and `jira-create`. Other tools work without it.
