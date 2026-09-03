# AC Coverage Check

Shared by `/ready-check` and `/mr-review`. Judges a changeset against a ticket's acceptance criteria. The caller owns any gating.

## Inputs

| Input | Meaning |
| --- | --- |
| `TICKET` | Acceptance criteria and dev notes, normally from the `atlassian-researcher` agent |
| `DIFF` | The command that prints the changeset under review |
| `TREE` | The path whose files reflect the post-change state |

## Method

1. Take each acceptance criterion from `TICKET` as a separate line item. Do not merge or reword them.
2. Look for evidence in `DIFF`. When the diff is ambiguous, read the surrounding file in `TREE`.
3. Judge implementation, not intent. A renamed variable is not an implemented AC.
4. Never grep a tree other than `TREE`. On a review of someone else's branch, the primary working tree holds different code.

## Rating scale

| Rating | Meaning |
| --- | --- |
| `✅ Done` | Implemented, and you can point at the file and line |
| `⚠️ Partial` | Some parts are implemented, something identifiable is absent |
| `❌ Missing` | No evidence in the changeset |

## Output format

```
## AC Coverage

✅ AC #1 - <description>
⚠️ AC #2 - <description>
   → Missing: <what is absent>
❌ AC #3 - <description>
   → No evidence in the changeset
```

## Reverse direction

Also report changeset content that no acceptance criterion asked for, even when every AC is `✅`:

```
Unrequested changes:
- <file> - <what it does, and why no AC covers it>
```

## Missing ticket data

- Ticket has no ACs: print `No ACs on the ticket` and stop. Do not invent criteria.
- No ticket ID, or Atlassian MCP unavailable: skip this check and say so in the caller's summary.
