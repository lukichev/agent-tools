---
name: skill-create
description: Create new skills, modify and improve existing skills. Use when users want to create a skill from scratch, turn a workflow into a reusable skill, update or optimize an existing skill, or improve a skill's description for better triggering accuracy. Also use when the user says "turn this into a skill", "make a skill for X", or "improve this skill".
argument-hint: "<skill name or description of what it should do>"
---

# Skill Creator

Create new skills and iteratively improve existing ones.

## Process Overview

1. Capture what the skill should do and when it should trigger
2. Write a draft SKILL.md
3. Test with realistic prompts, evaluate results
4. Improve based on feedback, repeat until satisfied
5. Optimize the description for reliable triggering

Be flexible — the user may already have a draft, may want to skip testing, or may just want to vibe. Meet them where they are.

## Capture Intent

Understand what the user wants before writing anything. If the conversation already contains a workflow the user wants to capture (e.g., "turn this into a skill"), extract answers from history first — tools used, sequence of steps, corrections made, input/output formats observed.

Questions to resolve:
1. What should this skill enable Claude to do?
2. When should it trigger? (what user phrases/contexts)
3. What's the expected output format?
4. Are there edge cases worth handling?

## Skill Anatomy

```
skill-name/
├── SKILL.md          (required — frontmatter + instructions)
└── references/       (optional — large docs, templates, schemas)
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

Only `description` is recommended. All other fields are optional.

| Field | Purpose |
|-------|---------|
| `name` | Display name and `/slash-command`. Lowercase, hyphens, max 64 chars |
| `description` | What + when. Claude uses this to decide when to auto-load |
| `argument-hint` | Shown during autocomplete (e.g., `<MR number>`) |
| `disable-model-invocation` | Set `true` to prevent Claude from auto-triggering. Default: `false` |
| `user-invocable` | Set `false` to hide from `/` menu. Use for background knowledge |
| `allowed-tools` | Restrict which tools Claude can use |
| `context` | `fork` to run in isolated subagent context |
| `agent` | Subagent type for `context: fork` (built-in or custom from `.claude/agents/`) |

### String substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking |
| `$ARGUMENTS[N]` or `$N` | Specific argument by 0-based index |
| `${CLAUDE_SESSION_ID}` | Current session ID |

### Dynamic context injection

Use the syntax `!` followed by a backtick-wrapped shell command to inject dynamic output before the skill is sent to Claude:

```markdown
Current branch: !{git branch --show-current}
Changed files: !{git diff main...HEAD --name-only}
```

(Note: in actual skill files, use backtick-wrapped commands after `!` — the syntax here is illustrative.)

Commands execute immediately and their output replaces the placeholder.

### Progressive Disclosure

Skills load in three levels:
1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when skill triggers (target < 500 lines)
3. **Bundled references** — loaded on demand (unlimited size)

Keep the body lean. If approaching 500 lines, split detailed reference material into `references/` with clear pointers about when to read them.

## Writing Guide

### Descriptions that trigger well

The description is the primary mechanism that determines whether Claude invokes a skill. Claude tends to under-trigger, so descriptions should be slightly pushy — include both what the skill does AND specific contexts for when to use it.

Bad: `"Create Jira tickets."`
Good: `"Create a Jira ticket with standard format (title, Summary, AC, Dev Notes). Shows draft for approval before creating. Use when the user wants to file a bug, create a story, or log a task in Jira — even if they don't say 'Jira' explicitly."`

### Explain the why, not just the what

Today's LLMs are smart. They have good theory of mind and when given a good harness can go beyond rote instructions. Instead of heavy-handed MUSTs and NEVERs, explain the reasoning so the model understands why something matters. That's more effective than rigid rules.

Yellow flag: if you're writing ALWAYS or NEVER in all caps repeatedly, try reframing as an explanation of why the thing is important.

When a hard constraint genuinely exists (e.g., "never replace an existing MR's title"), bold it and keep it — but make sure the reasoning is nearby.

### Use imperative form

Write instructions as commands: "Stage files", "Check for existing MR", "Show the draft to the user". Not "You should stage files" or "The skill will check for existing MR".

### Examples matter

Include concrete input/output examples. They communicate intent better than abstract rules:

```markdown
**Example:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Keep it lean

Remove instructions that aren't pulling their weight. Read transcripts of the skill in action — if the model wastes time on unproductive steps, cut the instructions causing that. Every line should earn its place.

### Generalize, don't overfit

Skills get used across many prompts and projects. Avoid fiddly changes that only work for specific examples. Instead of oppressively constrictive rules, use different metaphors or recommend different patterns. If a skill is project-agnostic, keep it that way.

### Domain organization

When a skill supports multiple frameworks or domains, organize by variant:

```
skill-name/
├── SKILL.md
└── references/
    ├── nestjs.md
    ├── express.md
    └── fastapi.md
```

Claude reads only the relevant reference file.

## Testing

After writing a draft, create 2-3 realistic test prompts — the kind of thing a real user would actually say. Run the skill on them and evaluate:

- Did it produce the right output?
- Did it follow the workflow without getting lost?
- Did it waste time on unnecessary steps?

Iterate: improve the skill, rerun tests, repeat until results are solid.

## Description Optimization

After the skill is working well, optimize the description for triggering accuracy:

1. **Write 16-20 eval queries** — a mix of should-trigger (8-10) and should-not-trigger (8-10)
2. Queries must be realistic and detailed, not abstract. Include file paths, personal context, casual speech, typos
3. Should-not-trigger queries should be near-misses that share keywords but need something different — not obviously irrelevant
4. Test the description against these queries and adjust wording to improve triggering accuracy

### Understanding triggering

Skills appear in Claude's available skills list with their name + description. Claude only consults skills for tasks it can't easily handle on its own — simple one-step queries may not trigger even with a perfect description match. Complex, multi-step, or specialized queries reliably trigger when the description matches. Design eval queries that are substantive enough to warrant consulting a skill.
