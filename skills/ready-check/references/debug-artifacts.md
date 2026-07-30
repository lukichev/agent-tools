# Debug Artifact Scan

Shared by `/ready-check` and `/mr-review`. Finds leftover debug code in a changeset.

## Inputs the caller must supply

| Input | Meaning |
| --- | --- |
| `DIFF` | The command that prints the changeset under review |

This file does **not** decide what happens next. The caller owns any gating.

## Scan

```bash
<DIFF> | grep -E "^(\+\+\+|@@|\+.*(console\.log|console\.debug|debugger|\.only\(|\.skip\(|// *TODO|// *FIXME|// *HACK|// *temp|XXX|dd\(\)|binding\.pry|print\())"
```

Keep the `+++` and `@@` lines: they carry the file name and the hunk start. `grep -n` over a diff returns the position in the stream, not the line in the file, so never report that number. Track the current file from the last `+++ b/<path>`, and the line from the hunk header `@@ -a,b +c,d @@`, counting added and context lines from `c`.

Rules:

- **Added lines only.** The `^\+` anchor is required. A pre-existing artifact is not this changeset's problem, and reporting it wastes the author's time.
- Ignore hits inside test fixtures and snapshot files, where some of these strings are legitimate content.
- `print(` matters in Python only. Drop the hit in other languages.
- Also flag commented-out code blocks of three or more consecutive lines.

## Output format

```
## Debug Artifacts

⚠️ src/auth/login.service.ts:42 - console.log
⚠️ src/jobs/listener.ts:18 - // TODO: remove this
```

When the scan is clean: `✅ No debug artifacts added`
