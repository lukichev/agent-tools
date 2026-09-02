# Debug Artifact Scan

Shared by `/ready-check` and `/mr-review`. Finds leftover debug code in a changeset. The caller owns any gating.

## Inputs

| Input | Meaning |
| --- | --- |
| `DIFF` | The command that prints the changeset under review |

## Scan

```bash
<DIFF> | sh ~/.claude/skills/ready-check/references/debug-scan.sh
```

The script prints `path:line - text` for every added line that holds a debug artifact, with the line number in the new file. Judge the hits: the rules below decide which ones to report.

Rules:

- **Added lines only.** The `^\+` anchor is required. A pre-existing artifact is not this changeset's problem.
- Ignore hits inside test fixtures and snapshot files, where these strings can be legitimate content.
- `print(` matters in Python only. Drop the hit in other languages.
- Also flag commented-out code blocks of three or more consecutive lines.

## Output format

```
## Debug Artifacts

⚠️ src/auth/login.service.ts:42 - console.log
⚠️ src/jobs/listener.ts:18 - // TODO: remove this
```

Clean scan: `✅ No debug artifacts added`
