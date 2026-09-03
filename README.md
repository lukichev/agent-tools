# agent-tools

Reusable Claude Code agents, skills and code style guides. Project-agnostic: copy or symlink into any project.

## Usage

Symlink or copy the directories into your project's `.claude/` folder. A symlink stays in sync:

```bash
ln -s /path/to/agent-tools/agents/ /your-project/.claude/agents
ln -s /path/to/agent-tools/skills/ /your-project/.claude/skills
# or
cp -r /path/to/agent-tools/{agents,skills} /your-project/.claude/
```

**The global symlinks are required.** Skills read each other by absolute path (`mr-review` reads `~/.claude/skills/ready-check/references/`, `git-publish` reads `~/.claude/skills/git-commit/`), and agents read guides the same way:

```bash
ln -s /path/to/agent-tools/skills        ~/.claude/skills
ln -s /path/to/agent-tools/agents        ~/.claude/agents
ln -s /path/to/agent-tools/guides        ~/.claude/guides
ln -s /path/to/agent-tools/output-styles ~/.claude/output-styles
```

Point at a guide from your project's `CLAUDE.md`. Never `@import` it: an import loads the full guide (2-7k tokens) into every session. A pointer line loads nothing until Claude reads the guide:

```markdown
## Code Style

Before writing or reviewing Angular code, read `~/.claude/guides/angular.md` and follow it.
```

Most agents and skills read the target project's `CLAUDE.md`. Document the tech stack, module structure, conventions and domain terminology there.

## Agents

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Review of a diff: bugs, security, performance, architecture, style. Run after code changes |
| `logic-reviewer` | Logic analysis of algorithms and business rules, or changeset review for coherence, scope and intent |
| `session-reflector` | Recover context lost to compaction, trace decisions, flag mistakes |
| `atlassian-researcher` | Research a ticket or topic across Jira and Confluence. Escalation mode adds history, regressions and recommendations |
| `claude-optimiser` | Audit CLAUDE.md, agents, skills, hooks, settings and model selection |

## Skills

### Git workflow

| Skill | Purpose |
|-------|---------|
| `/git-start` | Branch from latest main for a ticket or feature name, optionally in a worktree |
| `/git-commit` | Stage files and create a conventional commit |
| `/git-push` | Push the branch. Creates a feature branch first when on main |
| `/git-rebase` | Rebase onto the MR target or main. Handles squash-merged parents |
| `/git-rebase-all` | Rebase every open MR in waves, parents first, via subagents |
| `/git-cleanup` | Prune merged branches, worktrees, stashes and agent memories, with verification |
| `/git-publish` | `/git-commit`, `/git-push` and `/mr-create` in one flow |
| `/ready-check` | Pre-publish gate: AC coverage, applied migrations, debug artifacts, code review |

### GitLab merge requests

| Skill | Purpose |
|-------|---------|
| `/mr-create` | Create an MR, or update its description |
| `/mr-review` | Review an MR in a worktree: AC coverage, debug artifacts, hygiene, findings |
| `/mr-comment` | Post numbered `/mr-review` findings as inline diff comments |
| `/mr-status-check` | Dashboard of your open MRs: pipeline, comments, rebase, readiness |
| `/mr-watch` | One unattended tick: rebase safe MRs, report the delta. Built for `/loop` |

### Atlassian

| Skill | Purpose |
|-------|---------|
| `/jira-create` | Create a Jira ticket in the standard format |
| `/jira-roast` | Verify a ticket's claims, AC and hygiene against the code |
| `/atlassian-research` | Research a ticket or topic via `atlassian-researcher` |
| `/escalation-research` | Investigate an escalation via `atlassian-researcher` in escalation mode |

### Other

| Skill | Purpose |
|-------|---------|
| `/reflect` | Session retrospective via `session-reflector` |
| `/postman-export` | Postman collection from the endpoints on the current branch |
| `/skill-create` | Create a skill or improve an existing one |

## Guides

Read on demand (see Usage), never `@import`ed.

| Guide | Path |
|-------|------|
| Angular 21 | `~/.claude/guides/angular.md` |
| NestJS | `~/.claude/guides/nestjs.md` |
| Python 3.10+ | `~/.claude/guides/python.md` |
| Flutter / Dart | `~/.claude/guides/flutter.md` |
| ASD-STE100 writing | `~/.claude/guides/asd-ste100.md` |
| glab / GitLab API | `~/.claude/guides/glab-api.md` |

`guides/asd-ste100.md` holds the prose rules for MR descriptions, comments, tickets, commit messages, agent reports and documentation. Every agent reads it on demand, as does every skill that produces one of those artifacts. The rules apply to generated prose, not to this repo's instruction files.

The same file is an output style, which applies the rules to a whole session. `output-styles/asd-ste100.md` is a relative symlink to it. Select it under `/config`, **Output style**.

## Helpful Links

- [component.gallery](https://component.gallery/) - catalog of UI components across design systems

## Requirements

- **VCS**: GitLab (`glab` CLI)
- **Atlassian MCP**: required for `atlassian-researcher`, `jira-create` and `jira-roast`. Other tools work without it.
