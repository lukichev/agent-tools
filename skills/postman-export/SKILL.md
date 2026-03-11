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

### 2. Read the Project's CLAUDE.md

Understand the framework, routing conventions, and API structure:
- Framework (NestJS, Express, FastAPI, etc.)
- Global path prefix (e.g., `/api`, `/v2`)
- Auth mechanism (API key, Bearer, session)
- Host variable name used in existing collections

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

#### Collection structure

```json
{
  "info": {
    "name": "<TICKET-ID> — <Short Description>",
    "description": "Collection description with endpoint overview",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [ /* folders and requests */ ],
  "auth": { /* inherit from existing collection pattern or project convention */ },
  "variable": [
    { "key": "HOST", "value": "https://api.example.com" }
  ]
}
```

#### Request item format

```json
{
  "name": "Create Item",
  "request": {
    "method": "POST",
    "header": [
      { "key": "Content-Type", "value": "application/json" }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"name\": \"Example\"\n}",
      "options": { "raw": { "language": "json" } }
    },
    "url": {
      "raw": "{{HOST}}/api/items",
      "host": ["{{HOST}}"],
      "path": ["api", "items"],
      "query": [],
      "variable": []
    },
    "description": "Markdown description with field tables, roles, error codes"
  },
  "response": [
    {
      "name": "201 — Created",
      "originalRequest": { /* copy of request */ },
      "_postman_previewlanguage": "json",
      "header": [],
      "cookie": [],
      "body": "{ ... example response JSON ... }"
    }
  ]
}
```

#### Conventions

- **Host variable**: use the project's convention (check existing collections or CLAUDE.md). Default to `{{HOST}}`.
- **Auth**: inherit from collection level. Note endpoint-specific auth in description.
- **Path variables**: use `:paramName` in `raw` URL and list in `variable` array with `description: "Type | Required/Optional | Format"`
- **Query params**: list all in `query` array. Set `disabled: true` for optional params. Include `description` with type/constraints.
- **Body**: `mode: "raw"` with `options.raw.language: "json"`. Provide realistic example values.
- **Folders**: group related endpoints (e.g., "Users CRUD", "Auth")
- **Descriptions**: use markdown. Include roles required, error codes, field tables, pagination notes.
- **Response examples**: at least one example response per endpoint built from entity fields. Use `_postman_previewlanguage: "json"`.
- **`path` array**: split URL into segments. Path variables use `:paramName` (e.g., `":itemId"`).

### 6. Output

After writing the file, tell the user the path and that they can import it via Postman > Import > File.

## Rules

- Always read actual controller/route and DTO/schema source — never guess fields or types
- Match the format of any existing Postman collection in the project if one exists
- Check for enum values and include all valid options in descriptions
- For paginated endpoints, include pagination params with defaults
- Generate realistic example values (UUIDs, emails, dates) in response bodies
- **One request per endpoint** — list all query params (required and optional) on a single request item, using `disabled: true` for optional ones
