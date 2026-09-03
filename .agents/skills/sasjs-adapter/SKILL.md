---
name: sasjs-adapter
description: Frontend/Node integration with SAS backends using @sasjs/adapter — configuring the SASjs class, the exact request() inputs and response shape, authentication, file upload, and session management. Use when writing TypeScript/JavaScript that calls SAS services or jobs.
---

# @sasjs/adapter

`@sasjs/adapter` is the TypeScript library for calling SAS services/jobs from browsers or Node, with a unified API across three server types: `SAS9`, `SASVIYA`, `SASJS`.

## Basic setup

```ts
import SASjs from '@sasjs/adapter'

const sasjs = new SASjs({
  serverUrl: 'https://sas.example.com',
  serverType: 'SASVIYA',      // SAS9 | SASVIYA | SASJS
  appLoc: '/Public/app/myapp', // root folder of deployed services
  contextName: 'SAS Job Execution compute context', // Viya only
  debug: false
})
```

## request() — inputs (JS → SAS)

### Signature

```ts
sasjs.request(
  sasJob: string,
  data: { [key: string]: any[] } | null,
  config?: { [key: string]: any },             // merged over SASjsConfig
  loginRequiredCallback?: () => any,
  authConfig?: AuthConfig,                      // Viya tokens for Node usage
  extraResponseAttributes?: ExtraResponseAttributes[]  // ['log'] | ['file'] | ['data']
)
```

- `sasJob`: relative path (no leading slash) resolved against `appLoc`, or an absolute path. Becomes the SAS `_program` parameter.
- `data`: an object whose keys become **work datasets in SAS**. Can be `null` if the service takes no input.
- `config`: overrides merged on top of the constructor config for this call only.

### The `data` object — tables, not arbitrary JSON

Every key in `data` must be an **array of plain objects**. Each key becomes a SAS work dataset named after the key; each object in the array is a row; each property is a column.

```ts
const res = await sasjs.request('services/common/getdata', {
  customers: [
    { id: 1, name: 'Acme', active: true },
    { id: 2, name: 'Globex', active: false }
  ],
  config: [{ rootdir: '/tmp', retries: 3 }]  // even a single-row "config" table
})
```

On the SAS side these arrive as `work.customers` and `work.config`.

### Input validation rules

Before sending, the adapter validates `data` (see `validateInput`). Violations reject the promise with an `ErrorResponse`:

- `data` must be `null` or a plain object (not an array, not a primitive).
- Every table key must start with a letter or underscore: `/^[a-zA-Z_][a-zA-Z0-9_]*$/`. Numbers at the start are rejected.
- Table names cannot exceed **32 characters** (SAS name limit).
- Every value under a key must be an array of objects. Non-object rows are rejected.
- No property in any row may be `undefined` (it must be `null`, a string, a number, or a boolean).

### How tables are serialized to CSV

Each table is converted to CSV via `convertToCSV`. The conversion is type-aware:

- **String columns**: quoted only if they contain commas, tabs, newlines, or quotes. Internal `"` is escaped as `""`.
- **Numeric columns**: emitted unquoted.
- **Null / empty in a numeric column**: becomes `.` (SAS missing).
- **Column type inference**: the adapter scans all rows per column. If a column has both `null`/`number` values and special-missing strings (`.a`–`.z`, `_`), the column is typed as `best.`. Otherwise the first non-empty value determines `chars` vs `number`.
- **Column format header**: the first CSV line is a space-delimited format spec, e.g. `name:$char20. id:best.` — the SAS side uses this to assign informats.
- **Byte-size length check**: string values are measured in UTF-8 bytes. If any value exceeds **32765 bytes**, the request throws `The max length of a string value in SASjs is 32765 characters.`
- **Formats tables**: a key prefixed with `$` (e.g. `$customers`) is treated as a formats definition for the `customers` table and is not sent as a separate dataset. Its `formats` property maps column names to SAS formats.

### Two transport modes

The adapter picks the transport based on payload size and server type (see `WebJobExecutor`):

1. **Param-based** (default for Viya web / SASjs server, small payloads): each table's CSV is appended as a form field named `sasjs{N}data` (N = 1, 2, ...). A `sasjs_tables` field lists the table names space-separated. If a single CSV exceeds 16000 chars it is split into chunks: `sasjs{N}data0` holds the chunk count, `sasjs{N}data1..N` hold the pieces.
2. **File-upload** (SAS 9 always; Viya/SASjs when `JSON.stringify(data)` exceeds 500000 chars or contains a `;`): each table is appended as a CSV file (`{tableName}.csv`) in multipart form data.

In both cases the body is `multipart/form-data` with debug params (`_debug=131`, `_omittextlog=false`, `_omitSessionResults=false`) when `debug: true`.

## request() — outputs (SAS → JS)

### Response shape depends on `extraResponseAttributes`

**Default** (no `extraResponseAttributes`): the resolved value is **the parsed webout object directly** — whatever JSON the SAS service wrote to `_webout`:

```ts
// SAS service wrote: {"mydata":[{"COL1":"x","COL2":1}]}
const res = await sasjs.request('services/getdata', { in: [{ a: 1 }] })
// res === { mydata: [{ COL1: 'x', COL2: 1 }] }
// res.mydata[0].COL1  // note UPPERCASE column names
```

**With `extraResponseAttributes`** (e.g. `['log']`): the result is wrapped:

```ts
const res = await sasjs.request('services/getdata', { in: [{ a: 1 }] }, {}, undefined, undefined, ['log'])
// res === { result: { mydata: [...] }, log: '<sas log string>' }
```

`ExtraResponseAttributes` is `'file' | 'data' | 'log'`. Only `log` is fully implemented in current releases.

### Name casing

- **Table names** in the response are **lowercase** — this is enforced by the `%webout`/`mp_jsonout` macro on the SAS side, not the adapter. The adapter passes the webout JSON through as-is.
- **Column names** are **UPPERCASE** — SAS dataset variable names are uppercased by SAS itself, and the adapter does not re-case them.

### What the SAS service must produce

The service must write valid JSON to `_webout`. Conventionally via `%webout` (from @sasjs/core), which wraps `mp_jsonout`. The JSON shape is an object whose keys are table names, each mapping to an array of row objects:

```sas
%webout(OPEN)
%webout(OBJ, work.customers)   /* → {"customers":[{...}]} */
%webout(CLOSE)
```

### Debug mode

When `config.debug` is `true`:

- **SAS 9**: the raw response is a string containing the log plus the webout, delimited by `>>weboutBEGIN<<` and `>>weboutEND<<`. The adapter extracts the JSON between the markers.
- **Viya (web/JES)**: the debug response is parsed via `parseSasViyaDebugResponse` / `parseSasViyaLogDebugResponse`, which split out the log and the webout JSON.
- **Viya (compute API)**: the log is fetched separately from the compute session.

In all cases, with debug on and `extraResponseAttributes: ['log']`, the SAS log is available in `res.log`.

### Request history

Every executed request is appended to an in-memory history (capped at `requestHistoryLimit`, default 10):

```ts
sasjs.getSasRequests()
// SASjsRequest[]: { serviceLink, timestamp, sourceCode, generatedCode, logFile, SASWORK }
```

`sourceCode` and `generatedCode` are only populated when `debug: true`. The history is a ring buffer — oldest entries are dropped when the limit is exceeded.

## Authentication

- **SAS 9**: `sasjs.logIn(username, password)` (form-based against the stored process server). Session cookie is managed automatically.
- **Viya**: OAuth client/secret (client credentials grant) or authorization code flow; tokens are refreshed automatically. Configure via CLI (`sasjs add cred`) for Node usage. For Node, pass `authConfig` (client/secret/access/refresh tokens) to `request()`.
- **SASJS server**: token-based auth against the sasjs/server API.

## Key classes / modules

- `SASjs` — main facade: `request()`, `logIn()/logOut()`, `uploadFile()`, `executeScript()`, `startComputeJob()`, `deployServicePack()`
- `RequestClient` — HTTP layer; holds the request history (`getRequests()`), CSRF tokens, and auth headers
- `WebJobExecutor` — SAS 9 STP, Viya web JES, and SASjs server web (multipart form POST)
- `ComputeJobExecutor` — Viya compute API (direct code submission on a named context)
- `JesJobExecutor` — Viya JES API (job submission via the jobs API, not the web app)
- `SasjsJobExecutor` — SASjs server web execution
- `SessionManager` — Viya compute session lifecycle
- `SASViyaApiClient` / `SAS9ApiClient` / `SASjsApiClient` — low-level per-platform clients (rarely needed directly)
- `file/` utilities — file upload to SAS (binary content handling)

## Tips

- Set `debug: true` to surface the SAS log in responses while developing.
- Always handle `response.status` / error responses — SAS-side errors (e.g. from `%mp_abort`) come back in the JSON, not necessarily as HTTP errors.
- For large payloads prefer CSV upload or streamed files over JSON input tables.
- Keep `appLoc` consistent with the `appLoc` in `sasjsconfig.json` used to deploy.
- Column names come back UPPERCASE from SAS. If your frontend expects lowercase, map them in JS rather than trying to force SAS casing.
- `null` in a numeric input column becomes SAS missing (`.`); empty string in a char column becomes empty string. Don't use `undefined` — validation rejects it.

## Using the adapter without a bundler (zero-build / strict CSP frontends)

The package root `index.js` is a UMD bundle exposing a global `SASjs`. Pattern (from the minimal seed app):

1. `"prepare": "cp node_modules/@sasjs/adapter/index.js src/sasjs.js"` in package.json (runs on `npm i`).
2. `<script src="sasjs.js"></script>` before your app script.
3. Configure via a hidden custom element: `<sasjs serverType="SASJS" appLoc="/Public/app/myapp" debug="false"></sasjs>` and read attributes with `document.querySelector('sasjs')`. When the app is streamed by SAS itself, omit `serverUrl` — same-origin requests just work (CSP `default-src 'self'` safe).

## Limitations

This skill is a static reference for the @sasjs/adapter library — it provides guidance on the API, request/response shapes, authentication, and CSV serialization. It does not execute code, run shell commands, access the filesystem, connect to databases, or make network requests. All code examples are illustrative; the user must integrate them into their own application. References to authentication tokens describe what the adapter library manages at runtime — this skill does not read, write, or access those values itself.
