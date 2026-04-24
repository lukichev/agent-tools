---
name: postman-export
description: Generate Postman collection JSON from API controllers/routes on the current branch. Scans the diff, reads endpoints and DTOs/schemas, and writes a .postman_collection.json file.
argument-hint: "<module or path (optional)>"
disable-model-invocation: true
---

# Postman Export

Generate a Postman Collection v2.1 JSON file from API endpoints. Scans the current branch diff (or a specified module/path) and writes a `.postman_collection.json` file to `.claude/scratch/`.

## Workflow

### 1. Determine Scope

Check what the user wants endpoints for:
- **Current branch** (default): diff against `main` to find new/modified controllers/routes
- **Specific module**: user provides a path or module name

```bash
git branch --show-current  # for output filename
git diff main...HEAD --name-only -- '**/*controller*' '**/*route*' '**/*handler*'
```

### 2. Read Project Context

Read the project's `CLAUDE.md` for framework, routing conventions, auth mechanism, and API structure.

Then check for project-level Postman conventions:
```bash
# Look for project-specific collection format rules
find .claude -name 'postman*' -o -name 'POSTMAN*' 2>/dev/null
```
If a conventions file exists, read it and follow those rules (auth scheme, host variable, collection shell, folder structure, etc.). They override the defaults in this skill.

### 3. Read Controllers/Routes

For each endpoint file, extract:
- Base path (class-level route decorator or prefix)
- Whether it's excluded from any global prefix
- Each HTTP method and route
- Route params (`:id`, path variables) and their validators
- Request body schema/DTO class reference
- Query parameter schema/DTO class reference
- Status codes if explicitly set (otherwise use framework defaults)
- Auth/role requirements

### 4. Read DTOs/Schemas

For each referenced DTO, schema, or model class:
- Find the source file
- Extract fields, types, validators, defaults, and transforms
- Check for base class inheritance (e.g., pagination base adds `limit`/`offset`)

### 5. Generate Postman Collection JSON

Write to `.claude/scratch/<BRANCH-NAME>.postman_collection.json`.

### 6. Output

After writing the file, tell the user the path and that they can import it via Postman > Import > File.

---

## Collection Format Defaults

Use Postman Collection v2.1 schema. These defaults apply when no project-level conventions file exists.

### Collection Shell

```json
{
  "info": {
    "name": "<TICKET-ID> — <Short Description>",
    "description": "Markdown description of what this collection covers",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [],
  "auth": { /* derive from project context */ },
  "variable": [
    { "key": "HOST", "value": "https://api.example.com" }
  ]
}
```

### Non-Obvious Format Rules

These are easy to get wrong — standard v2.1 knowledge is assumed.

- **Auth inheritance**: set auth at collection level. Do NOT set `auth` on individual requests unless overriding. Use `"auth": { "type": "noauth" }` for unauthenticated endpoints.
- **`raw` URL**: optional query params are NOT appended in the request template — only in `originalRequest` inside response examples (with values filled in).
- **Path variables**: keep `:` prefix in path array (e.g., `":accountId"`). Always include `description` on every path variable.
- **Query params**: all params (required and optional) go in the `query` array. Set `"disabled": true` for optional ones.
- **Description format** for path vars and query params: `"Type | Required/Optional | Constraint"` — include enum values where applicable (e.g., `"ASC | DESC"`).
- **JSON body**: always include `options.raw.language: "json"`. JSON comments (`// description`) are allowed in `raw` for inline field docs.
- **Formdata file fields**: use `"type": "file"` with `"src": ""`. Do NOT use `postman-cloud://` URLs.
- **GET with empty body**: add `"protocolProfileBehavior": { "disableBodyPruning": true }` at the request-item level.
- **Response examples**: at least one success response per endpoint. `originalRequest` is a full copy of the request with all values filled in. Include error responses (400, 404) for notable error cases.
- **One request per endpoint** — list all query params on a single request item.

## General Rules

- Always read actual controller/route and DTO/schema source — never guess fields or types
- For paginated endpoints, include pagination params with defaults
- Body field descriptions can use `//` comments inside raw JSON or go in the endpoint description
