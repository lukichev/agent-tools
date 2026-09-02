---
name: ready-check
description: Pre-publish gate - fetches ticket ACs, checks implementation completeness, scans for debug artifacts, then runs a code review. Use before /git-publish. Use when the user wants to check if their work is ready, says "am I done?", "is this ready?", or "check before publishing".
argument-hint: "<ticket ID, e.g. PROJ-1234>"
disable-model-invocation: true
---

# Ready Check

Pre-publish gate. Verifies that the implementation is complete and clean before `/git-publish`.

## Workflow

### 1. Detect the ticket ID

The argument, else the current branch name (`PROJ-1234`), else `AskUserQuestion`.

### 2. Get the diff

```bash
git diff main...HEAD --name-only    # list of changed files
git diff main...HEAD                 # full diff for analysis
```

### 3. Research the ticket

Launch the `atlassian-researcher` agent for the acceptance criteria, Dev Notes and linked tickets. Confluence off unless the user asks.

No ticket ID, or no Atlassian MCP: skip steps 3 and 4 and note it in the summary.

### 4. AC completeness

Read `references/ac-coverage.md` and follow it with:

- `TICKET` = the step 3 output
- `DIFF` = `git diff main...HEAD`
- `TREE` = `$(git rev-parse --show-toplevel)`

**Gate:** all ACs ✅, say so and continue. Any ⚠️ or ❌, flag them and ask the user whether to continue.

### 5. Migration applied locally

Skip when the diff adds no migration.

Every migration in the diff must already be applied to the local database. TypeORM records each applied migration as a row in the table named by `migrationsTableName` in the data source config. The `name` column holds the class name, so `1786964751641-CreateGuestDomain.ts` is stored as `CreateGuestDomain1786964751641`.

Read the table name, database service, user, database and password from the project's `CLAUDE.md` or its compose file. Never hard-code them here.

Pick the query by engine and substitute the project's values:

```bash
# Postgres
docker compose exec -T <postgres-service> psql -U <user> -d <db> -t \
  -c "SELECT name FROM <migrations-table> ORDER BY timestamp DESC LIMIT 20;"

# MySQL
docker compose exec -T <mysql-service> mysql -u <user> -p<password> <db> -N \
  -e "SELECT name FROM <migrations-table> ORDER BY timestamp DESC LIMIT 20;"
```

**Hard gate.** A migration with no row blocks publishing. Say which migration is missing and stop. Do not ask whether to continue, and do not run `/git-publish`. An unapplied migration never ran, so nothing proves it runs or that the entities match its schema.

Also confirm the row's `name` matches the class name in the file. A mismatch means the file was renamed after it ran, so the row points at a class that no longer exists.

### 6. Debug artifact scan

Read `references/debug-artifacts.md` and follow it with `DIFF` = `git diff main...HEAD`.

### 7. Code review

Launch the `code-reviewer` agent with the changed files from step 2 and the diff, so it reviews only what changed.

### 8. Summary

Omit the Migrations line when the diff adds none:

```
## Ready Check Summary

Ticket: PROJ-XXXX - <title>

AC Completeness:  ✅ 3/3 done
Migrations:       ✅ Applied locally / ⛔ NOT applied - publishing blocked
Debug Artifacts:  ✅ Clean
Code Review:      ✅ No blockers / ⚠️ N suggestions

→ Ready to /git-publish  OR  → Fix the above before publishing
```
