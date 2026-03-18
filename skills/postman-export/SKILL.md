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

Use the Documo collection format rules below. Do NOT read the reference collection (`Documo Beta API Documentation.postman_collection.json`) — everything you need is in this skill file.

### 6. Output

After writing the file, tell the user the path and that they can import it via Postman > Import > File.

---

## Documo Collection Format Rules

These rules are derived from the existing `Documo Beta API Documentation` Postman collection and must be followed exactly.

### Collection Shell

```json
{
  "info": {
    "name": "<TICKET-ID> — <Short Description>",
    "description": "Markdown description of what this collection covers",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [],
  "auth": {
    "type": "apikey",
    "apikey": [
      { "key": "value", "value": "Basic {{API_KEY}}", "type": "string" },
      { "key": "key", "value": "Authorization", "type": "string" }
    ]
  },
  "event": [
    { "listen": "prerequest", "script": { "type": "text/javascript", "exec": [""] } },
    { "listen": "test", "script": { "type": "text/javascript", "exec": [""] } }
  ],
  "variable": [
    { "key": "FUSION_HOST", "value": "https://api.documo.com" }
  ]
}
```

### Host Variable

Always use `{{FUSION_HOST}}` — never `{{HOST}}` or any other name.

- `host` array is always `["{{FUSION_HOST}}"]`
- `raw` URL starts with `{{FUSION_HOST}}/...`

### Auth

- Collection-level auth is `apikey` type: `Authorization: Basic {{API_KEY}}` (see shell above).
- Endpoints inherit collection auth by default — do NOT set `auth` on individual requests unless overriding.
- For endpoints that require no auth, set `"auth": { "type": "noauth" }` on the request object.

### Folder Structure

- Up to 3 levels of nesting: `Top Folder > Sub Folder > Request`
- Folders can have a `"description"` field (markdown) for context.
- Group by domain (e.g., "Reports", "Numbers", "Workspaces"), then by sub-feature (e.g., "Provisioning", "Porting").

### URL Object

```json
{
  "raw": "{{FUSION_HOST}}/fax/v2/reports/usage/:accountId/total?dateStart=&dateEnd=",
  "host": ["{{FUSION_HOST}}"],
  "path": ["fax", "v2", "reports", "usage", ":accountId", "total"],
  "query": [],
  "variable": []
}
```

- **`path` array**: split URL by `/`. Path variables keep the `:` prefix (e.g., `":accountId"`).
- **`raw`**: full URL string. Optional query params are NOT appended to `raw` in the request template — only in `originalRequest` inside response examples (where they have example values filled in).

### Path Variables (`variable` array)

```json
{ "key": "accountId", "value": "", "description": "String | Required | UUID" }
```

- `value`: empty string `""` in request template. Filled with example UUID in `originalRequest` of response examples.
- `description` format: `"Type | Required/Optional | Format"` (e.g., `"String | Required | UUID"`)
- **Always include `description`** on every path variable. The existing collection has a few missing descriptions — do not replicate that; always provide them.

### Query Parameters (`query` array)

```json
{ "key": "dateStart", "value": "", "description": "String | Required | Start date as ISO 8601 string", "disabled": true }
```

- **All query params** go in the `query` array (both required and optional).
- Set `"disabled": true` for optional params. Required params can also be `disabled: true` in the request template (the response example's `originalRequest` shows them enabled with values).
- `description` format: `"Type | Required/Optional | Constraint"` — e.g.:
  - `"String | Required | Start date as ISO 8601 string"`
  - `"Boolean | Default: true"`
  - `"Max 500"`
  - `"inbound | outbound"` (enum values)
  - `"reseller | customer | department | subaccount"` (enum values)
  - `"ASC | DESC"` (enum values)
  - `"String | 2 letter country code | ISO 3166-1 alpha-2"`
- `value`: empty string or `null` in request template. Realistic values in response example's `originalRequest`.
- Some params only have a short description with enum values (no "Type | Required" prefix) — that's acceptable.

### Request Body Modes

#### JSON body (`mode: "raw"`)

```json
{
  "mode": "raw",
  "raw": "{\n    \"name\": \"Testing Workspace API\",\n    \"accountId\": \"efaa36f7-d9a0-493f-a3aa-0cb1114eea09\"\n}",
  "options": { "raw": { "language": "json" } }
}
```

- Always include `options.raw.language: "json"`.
- `raw` contains a JSON string with realistic example values.
- JSON comments (`// description`) are allowed in `raw` for field documentation (Postman tolerates this).

#### URL-encoded body (`mode: "urlencoded"`)

```json
{
  "mode": "urlencoded",
  "urlencoded": [
    {
      "key": "numbers",
      "value": "12063505633,12063505654",
      "description": "String | Required | Comma separated list of E164-LITE formatted numbers",
      "type": "text"
    }
  ]
}
```

- Each field has `key`, `value` (with example), `description`, and `type: "text"`.
- Description format matches query param style.

#### Multipart form data (`mode: "formdata"`)

```json
{
  "mode": "formdata",
  "formdata": [
    { "key": "name", "value": "dummy.pdf", "description": "File name", "type": "text" },
    { "key": "file", "description": "File", "type": "file", "src": "" }
  ]
}
```

- Text fields: `"type": "text"` with `value` and `description`.
- File fields: `"type": "file"` with `"src": ""` (empty — user picks file in Postman).
- Do NOT use `postman-cloud://` URLs for `src`.

#### Empty / no body

- For GET requests with no body: omit `body` entirely, or use `"body": { "mode": "raw", "raw": "", "options": { "raw": { "language": "json" } } }`.
- When a GET has an empty raw body, add `"protocolProfileBehavior": { "disableBodyPruning": true }` at the request-item level (sibling of `"request"`).
- For DELETE/PUT with no body: omit `body` entirely.

### Request Headers

- Do NOT add `Content-Type` headers manually — Postman infers them from body mode.
- Custom headers (non-standard) go in the `header` array with `key`, `value`, and optional `description`.
- Most endpoints have `"header": []` (empty array).

### Endpoint Description

Use markdown with this structure:

```markdown
This endpoint does X for Y.

### Request

- Path Parameter:
    - `paramName` (type, required/optional): Description.
- Query Parameter:
    - `paramName` (type, required/optional): Description.
- Body:
    - `fieldName` (type, required/optional): Description.

### Response

Description of response format.
```

- Keep descriptions concise but complete.
- List all path params, query params, and body fields.
- Note pagination, filtering, and sorting options.

### Response Examples

```json
{
  "name": "Descriptive Name - OK",
  "originalRequest": { /* full copy of request with example values filled in */ },
  "_postman_previewlanguage": "json",
  "header": [],
  "cookie": [],
  "body": "{\n    \"field\": \"value\"\n}"
}
```

#### Rules:

- **At least one success response** per endpoint.
- **`originalRequest`**: full copy of the request with path variables filled with example UUIDs, query params enabled with example values, and body with realistic data.
- **`body`**: JSON string (escaped). Use realistic example data — UUIDs, names, timestamps, etc. For 204 No Content responses, `body` is `""` (empty string) or omitted.
- **`_postman_previewlanguage`**:
  - `"json"` for success responses that return a JSON body (the default — use this for all new responses with JSON content).
  - Omit or set to `"plain"` for 204 No Content responses (no body).
  - For error responses (400, 404), use `"json"` since they typically return JSON error objects.
- **`header`**: always `[]`.
- **`cookie`**: always `[]`.
- **`status`** and **`code`**: include when known (e.g., `"status": "OK", "code": 200`). Omit if unknown — some responses in the existing collection lack these. Common codes: `200`, `201`, `204`, `400`, `404`.
- **`name`** conventions:
  - Success: `"Endpoint Name"` or `"Endpoint Name - OK"` or descriptive like `"Total User Account Report"`.
  - Errors: `"Endpoint Name - Validation failed (Route parameter)"`, `"Endpoint Name - Not found"`, etc.
- **Multiple responses**: include error responses (400, 404) when the endpoint has notable error cases. Name pattern: `"Action - Error description"`.

### Naming Conventions

- **Request names**: short, action-oriented (e.g., `"Usage Total"`, `"Create Workspace"`, `"Upload Port Document"`).
- **Response names**: either match the request name, use descriptive labels (e.g., `"Total Subaccount Report"`), or use the `"Action - Status"` pattern for multiple responses.

### Collection Variables

When generating a collection, include only `FUSION_HOST`. Add additional type-placeholder variables only if the collection has many endpoints that reuse them:

```json
{ "key": "FUSION_HOST", "value": "https://api.documo.com" }
```

Optional (include if broadly used across the collection):

```json
{ "key": "uuid", "value": "d1077489-5ea1-4db1-9760-853f175e8288" },
{ "key": "string", "value": "example" },
{ "key": "int", "value": "1" },
{ "key": "bool", "value": "false" },
{ "key": "date", "value": "2023-01-01T00:00:00.000Z" },
{ "key": "phone", "value": "1234567890" },
{ "key": "e164Phone", "value": "+19999999999" }
```

## General Rules

- Always read actual controller/route and DTO/schema source — never guess fields or types
- Check for enum values and include all valid options in descriptions
- For paginated endpoints, include pagination params with defaults (`offset`, `limit` with max noted)
- Generate realistic example values (UUIDs, emails, dates, names) in response bodies
- **One request per endpoint** — list all query params (required and optional) on a single request item
- Use `disabled: true` for optional query params
- Body field descriptions can use `//` comments inside raw JSON or go in the endpoint description
- Keep the JSON pretty-printed (2-space or 4-space indent) in the output file
