---
name: postman-export
description: Generate Postman collection JSON from API controllers/routes on the current branch. Scans the diff, reads endpoints and DTOs/schemas, and writes a .postman_collection.json file.
argument-hint: "<module or path (optional)>"
disable-model-invocation: true
---

# Postman Export

Generate a Postman Collection v2.1 JSON file from the API endpoints in the current branch diff, or in a given module or path. Write it to `.claude/scratch/`.

## Workflow

### 1. Determine Scope

- **Current branch** (default): diff against `main` for new or modified controllers and routes
- **Specific module**: the path or module name the user gave

```bash
git branch --show-current  # for output filename
git diff main...HEAD --name-only -- '**/*controller*' '**/*route*' '**/*handler*'
```

### 2. Read Project Context

Read the project's `CLAUDE.md` for framework, routing conventions, auth mechanism, and API structure.

Check for project-level Postman conventions:
```bash
find .claude -name 'postman*' -o -name 'POSTMAN*' 2>/dev/null
```
If a conventions file exists, follow it (auth scheme, host variable, collection shell, folder structure). It overrides the defaults below.

### 3. Read Controllers/Routes

For each endpoint file, extract:
- Base path (class-level route decorator or prefix)
- Exclusion from any global prefix
- Each HTTP method and route
- Route params (`:id`, path variables) and their validators
- Request body DTO or schema reference
- Query parameter DTO or schema reference
- Status codes when set explicitly, else framework defaults
- Auth and role requirements

### 4. Read DTOs/Schemas

For each referenced DTO, schema, or model class:
- Find the source file
- Extract fields, types, validators, defaults, and transforms
- Check base class inheritance (a pagination base adds `limit` and `offset`, for example)

### 5. Write the Collection

Write to `.claude/scratch/<BRANCH-NAME>.postman_collection.json`.

### 6. Output

Tell the user the path and that Postman > Import > File loads it.

## Collection Format Defaults

Postman Collection v2.1 schema. These apply when no project-level conventions file exists.

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

Standard v2.1 knowledge is assumed. These are the rules that are easy to get wrong.

- **Auth inheritance**: set auth at collection level. Do NOT set `auth` on individual requests unless overriding. Use `"auth": { "type": "noauth" }` for unauthenticated endpoints.
- **`raw` URL**: optional query params are NOT appended in the request template, only in `originalRequest` inside response examples (with values filled in).
- **Path variables**: keep the `:` prefix in the path array (`":accountId"`). Include `description` on every path variable.
- **Query params**: all params, required and optional, go in the `query` array. Set `"disabled": true` for optional ones.
- **Description format** for path vars and query params: `"Type | Required/Optional | Constraint"`. Include enum values where applicable (`"ASC | DESC"`).
- **JSON body**: include `options.raw.language: "json"`. JSON comments (`// description`) are allowed in `raw` for inline field docs.
- **Formdata file fields**: use `"type": "file"` with `"src": ""`. Do NOT use `postman-cloud://` URLs.
- **GET with empty body**: add `"protocolProfileBehavior": { "disableBodyPruning": true }` at the request-item level.
- **Response examples**: at least one success response per endpoint. `originalRequest` is a full copy of the request with all values filled in. Include error responses (400, 404) for notable error cases.
- **One request per endpoint**: list all query params on a single request item.

## General Rules

- Read the controller, route, DTO and schema source. Never guess fields or types.
- For paginated endpoints, include pagination params with defaults.
- Body field descriptions go in `//` comments inside raw JSON or in the endpoint description.
