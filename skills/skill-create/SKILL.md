---
name: skill-create
description: Create new skills, modify and improve existing skills. Use when users want to create a skill from scratch, turn a workflow into a reusable skill, update or optimize an existing skill, or improve a skill's description for better triggering accuracy. Also use when the user says "turn this into a skill", "make a skill for X", or "improve this skill".
argument-hint: "<skill name or description of what it should do>"
disable-model-invocation: true
---

# Skill Creator

## Process

1. Capture what the skill does and when it triggers
2. Write a draft SKILL.md
3. Test with realistic prompts
4. Improve from the results, repeat
5. Optimize the description for triggering

The user may already have a draft or may skip testing. Start where they are.

## Capture Intent

If the conversation already holds the workflow ("turn this into a skill"), extract from history first: tools used, sequence of steps, corrections made, input and output formats.

Resolve:
1. What does the skill enable Claude to do?
2. When does it trigger? Which user phrases and contexts?
3. What is the output format?
4. Which edge cases matter?

## Skill Anatomy

```
skill-name/
├── SKILL.md          (required: frontmatter + instructions)
└── references/       (optional: large docs, templates, schemas)
```

### Frontmatter

```yaml
---
name: skill-name
description: What it does and when to trigger. Be specific and slightly "pushy".
argument-hint: "<what the user passes>"
disable-model-invocation: false  # set true to prevent Claude from auto-triggering
user-invocable: false            # only Claude can invoke (for background knowledge)
allowed-tools: Read, Grep, Glob  # restrict tools when skill is active
context: fork                    # run in isolated subagent
agent: agent-name                # which agent to use with context: fork
---
```

Only `description` is recommended. The rest is optional.

| Field | Purpose |
|-------|---------|
| `name` | Display name and `/slash-command`. Lowercase, hyphens, max 64 chars |
| `description` | What + when. Claude uses it to decide when to auto-load |
| `argument-hint` | Shown during autocomplete, for example `<MR number>` |
| `disable-model-invocation` | `true` prevents Claude from auto-triggering. Default `false` |
| `user-invocable` | `false` hides the skill from the `/` menu. For background knowledge |
| `allowed-tools` | Restrict which tools Claude can use |
| `context` | `fork` runs the skill in an isolated subagent |
| `agent` | Subagent type for `context: fork`, built-in or from `.claude/agents/` |

### String substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed on invocation |
| `$ARGUMENTS[N]` or `$N` | Argument by 0-based index |
| `${CLAUDE_SESSION_ID}` | Current session ID |

### Dynamic context injection

Prefix a backtick-wrapped shell command with `!` to inject its output before the skill reaches Claude. See `atlassian-research/SKILL.md` for an example.

### Progressive Disclosure

Skills load in three levels:
1. **Metadata** (name + description): always in context, about 100 words
2. **SKILL.md body**: loaded when the skill triggers, target under 500 lines
3. **Bundled references**: loaded on demand, unlimited size

Near 500 lines, move reference material into `references/` and say when to read each file.

## Writing Guide

### Prose the skill generates

If the skill writes prose for a human (a comment, a description, a ticket, a report), point at `~/.claude/guides/asd-ste100.md`. Do not restate the rules. Add only limits specific to the artifact, such as a word cap or a section structure.

A skill that only runs commands or edits code needs no pointer.

### Descriptions that trigger well

The description decides whether Claude invokes the skill. Claude under-triggers, so include both what the skill does and the contexts where it applies.

Bad: `"Create Jira tickets."`
Good: `"Create a Jira ticket with standard format (title, Summary, AC, Dev Notes). Shows draft for approval before creating. Use when the user wants to file a bug, create a story, or log a task in Jira - even if they don't say 'Jira' explicitly."`

### Explain the why

State the reason behind a rule instead of a bare MUST or NEVER. Repeated ALWAYS or NEVER in capitals is a sign to reframe. Keep a hard constraint ("never replace an existing MR's title") in bold, with the reason beside it.

### Use imperative form

"Stage files", "Check for existing MR", "Show the draft to the user". Not "You should stage files" or "The skill will check".

### Examples

Concrete input and output examples carry intent better than abstract rules:

```markdown
**Example:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Keep it lean

Read transcripts of the skill in action. If the model wastes time on a step, cut the instruction that causes it.

### Generalize

Skills run across many prompts and projects. Avoid rules that only fit one example. Keep a project-agnostic skill project-agnostic.

### Domain organization

When a skill supports several frameworks, organize by variant, and Claude reads only the matching file:

```
skill-name/
├── SKILL.md
└── references/
    ├── nestjs.md
    ├── express.md
    └── fastapi.md
```

## Testing

Write 2-3 realistic test prompts. Run the skill on them and check:

- Did it produce the right output?
- Did it follow the workflow without losing its place?
- Did it spend time on unneeded steps?

Improve, rerun, repeat.

## Description Optimization

Once the skill works:

1. Write 16-20 eval queries: 8-10 should-trigger, 8-10 should-not-trigger
2. Make them realistic and detailed: file paths, personal context, casual speech, typos
3. Make should-not-trigger queries near-misses that share keywords but need something else
4. Test the description against them and adjust the wording

Claude consults skills only for tasks it cannot handle in one step, so a simple query may not trigger even a matching description. Write eval queries substantive enough to warrant a skill.
