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

Read `references/ac-coverage.md` and follow it with these inputs:

- `TICKET` = the research output from step 3
- `DIFF` = `git diff main...HEAD`
- `TREE` = `$(git rev-parse --show-toplevel)`

**Then apply this gate, which is specific to this skill:** if all ACs are ✅, say so and continue. If any are ⚠️ or ❌, flag them and **ask the user whether to continue** before the next steps.

### 5. Debug Artifact Scan

Read `references/debug-artifacts.md` and follow it with `DIFF` = `git diff main...HEAD`.

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

- Never auto-proceed past a ⚠️ or ❌ AC — always ask the user first
- Skip the code review only when the user declines to continue past a ❌
- If no ticket ID can be found, or Atlassian MCP is not configured, skip steps 3-4 and note it in the summary
