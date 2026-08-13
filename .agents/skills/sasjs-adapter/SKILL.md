---
name: sasjs-adapter
description: Frontend/Node integration with SAS backends using @sasjs/adapter — configuring the SASjs class, authentication (SAS 9, Viya, SASjs server), executing requests with input/output tables, file upload, and session/context management. Use when writing TypeScript/JavaScript that calls SAS services or jobs.
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

## Executing a request

```ts
const response = await sasjs.request('services/common/getdata', {
  mytable: [{ col1: 'value', col2: 42 }]   // input tables as JS arrays of objects
})
// response.result contains output tables sent back from SAS (_webout JSON)
```

- Input tables become SAS datasets via the `sasjs_tables` mechanism (work tables named after the JS keys).
- The SAS service must write JSON to `_webout` — conventionally with the `mp_jsonout` macro from @sasjs/core, wrapped in `proc stp`-style begin/end macros.
- Responses follow the `SASjsRequest`/`SASjsResponse` types; check `response.result` for tables and `response.log` where available.

## Authentication

- **SAS 9**: `sasjs.logIn(username, password)` (form-based against the stored process server). Session cookie is managed automatically.
- **Viya**: OAuth client/secret (client credentials grant) or authorization code flow; tokens are refreshed automatically. Configure via CLI (`sasjs add cred`) for Node usage.
- **SASJS server**: token-based auth against the sasjs/server API.

## Key classes / modules

- `SASjs` — main facade: `request()`, `logIn()/logOut()`, `uploadFile()`, `executeScript()`
- `SessionManager` — Viya compute session lifecycle
- `ContextManager` — Viya compute context selection
- `SASViyaApiClient` / `SAS9ApiClient` / `SASjsApiClient` — low-level per-platform clients (rarely needed directly)
- `file/` utilities — file upload to SAS (binary content handling)

## Tips

- Set `debug: true` to surface the SAS log in responses while developing.
- Always handle `response.status` / error responses — SAS-side errors (e.g. from `%mp_abort`) come back in the JSON, not necessarily as HTTP errors.
- For large payloads prefer CSV upload or streamed files over JSON input tables.
- Keep `appLoc` consistent with the `appLoc` in `sasjsconfig.json` used to deploy.
