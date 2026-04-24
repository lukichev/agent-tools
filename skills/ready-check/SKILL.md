---
name: ready-check
description: Pre-publish gate — fetches ticket ACs, checks implementation completeness, scans for debug artifacts, then runs a code review. Use before /git-publish. Use when the user wants to check if their work is ready, says "am I done?", "is this ready?", or "check before publishing".
argument-hint: "<ticket ID, e.g. PROJ-1234>"
disable-model-invocation: true
---

# Ready Check

Pre-publish gate that verifies the implementation is complete and clean before running `/git-publish`.

## Workflow

### 1. Detect Ticket ID

- Use the argument if provided
- Otherwise try to detect from the current branch name (e.g. `PROJ-1234` → ticket `PROJ-1234`)
- If still not found, ask the user with `AskUserQuestion`

### 2. Get the Diff

```bash
git diff main...HEAD --name-only    # list of changed files
git diff main...HEAD                 # full diff for analysis
```

### 3. Research the Ticket

Launch the `atlassian-researcher` agent to fetch:
- Acceptance Criteria (ACs)
- Dev Notes
- Any linked tickets

Skip Confluence search unless the user says otherwise.

### 4. AC Completeness Check

For each AC item found in the ticket, evaluate it against the diff and changed files.

Rate each AC:
- `✅ Done` — clearly implemented in the diff
- `⚠️ Partial` — some parts done, something looks missing
- `❌ Missing` — no evidence of implementation

Output format:

```
## AC Completeness

✅ AC #1 — <description>
⚠️ AC #2 — <description>
   → Missing: <what seems absent>
❌ AC #3 — <description>
   → Not found in diff
```

If all ACs are ✅, say so and continue. If any are ⚠️ or ❌, flag them clearly and **ask the user whether to continue** before proceeding to the next steps.

### 5. Debug Artifact Scan

Search changed files for leftover debug artifacts:

```bash
git diff main...HEAD -- <changed-files> | grep -n "console\.log\|debugger\|\/\/ TODO\|\/\/ FIXME\|\/\/ temp\|\.only("
```

Also check for commented-out code blocks (3+ consecutive commented lines).

Report findings as:

```
## Debug Artifacts

⚠️ src/auth/login.service.ts:42 — console.log
⚠️ src/jobs/listener.ts:18 — // TODO: remove this
```

If none found: `✅ No debug artifacts found`

### 6. Code Review

Launch the `code-reviewer` agent via the Agent tool, scoped to the changed files from step 2.

Pass the list of changed files and the diff as context so the agent focuses only on what was modified.

### 7. Summary

Output a final pre-publish summary:

```
## Ready Check Summary

Ticket: PROJ-XXXX — <title>

AC Completeness:  ✅ 3/3 done
Debug Artifacts:  ✅ Clean
Code Review:      ✅ No blockers / ⚠️ N suggestions

→ Ready to /git-publish  OR  → Fix the above before publishing
```

## Rules

- Never auto-proceed past a ⚠️ AC — always ask the user first
- Don't run code review if ACs have ❌ items (no point reviewing incomplete work)
- Keep the summary tight — details are in the sections above it
- If no ticket ID can be found, skip steps 3–4 and note it in the summary
- If Atlassian MCP is not configured, skip steps 3–4 and note it in the summary
