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

### 5. Migration Applied Locally

Skip this step when the diff adds no migration.

Every migration in the diff must already be applied to the local database. The ORM records
each applied migration as a row in its migrations meta table. TypeORM names that table in the
data source config (`migrationsTableName`) and stores the class name in the `name` column,
so `1786964751641-CreateGuestDomain.ts` is stored as `CreateGuestDomain1786964751641`.

Read the table name, the database service, the user, the database and the password from the
project's `CLAUDE.md` or its compose file. Never hard-code them into this skill.

Pick the query by the migration's engine and substitute the project's values:

```bash
# Postgres
docker compose exec -T <postgres-service> psql -U <user> -d <db> -t \
  -c "SELECT name FROM <migrations-table> ORDER BY timestamp DESC LIMIT 20;"

# MySQL
docker compose exec -T <mysql-service> mysql -u <user> -p<password> <db> -N \
  -e "SELECT name FROM <migrations-table> ORDER BY timestamp DESC LIMIT 20;"
```

**This is a hard gate.** If any migration in the diff has no row, publishing is not
allowed. Say which migration is missing, and stop — do not offer to continue and do not run
`/git-publish`. An unapplied migration means it was never executed even once, so nothing
proves it runs, and nothing proves the entities match the schema it creates.

Also confirm the row's `name` matches the class name in the file. A mismatch means the file
was renamed after it ran, so the recorded row points at a class that no longer exists.

### 6. Debug Artifact Scan

Read `references/debug-artifacts.md` and follow it with `DIFF` = `git diff main...HEAD`.

### 7. Code Review

Launch the `code-reviewer` agent via the Agent tool, scoped to the changed files from step 2.

Pass the list of changed files and the diff as context so the agent focuses only on what was modified.

### 8. Summary

Output a final pre-publish summary. Omit the Migrations line when the diff adds none:

```
## Ready Check Summary

Ticket: PROJ-XXXX — <title>

AC Completeness:  ✅ 3/3 done
Migrations:       ✅ Applied locally / ⛔ NOT applied — publishing blocked
Debug Artifacts:  ✅ Clean
Code Review:      ✅ No blockers / ⚠️ N suggestions

→ Ready to /git-publish  OR  → Fix the above before publishing
```

## Rules

- If no ticket ID can be found, or Atlassian MCP is not configured, skip steps 3-4 and note it in the summary
- An unapplied migration blocks publishing outright. Do not ask whether to continue, and do not run `/git-publish`.
