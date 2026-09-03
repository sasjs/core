---
name: sasjs-server
description: Installing, configuring, and running @sasjs/server — the open-source NodeJS wrapper around the SAS binary that provides a REST API, filesystem (SASjs Drive), Stored Program execution, and web app streaming. Covers desktop vs server modes, runtimes (SAS/JS/Python/R), env vars, auth (tokens, LDAP), and mock servers. Use when deploying, troubleshooting, or developing against sasjs/server.
---

# @sasjs/server

SASjs Server is an open-source NodeJS wrapper for calling the SAS binary executable. It runs on a real SAS server or a local desktop and provides:

- A filesystem (SASjs Drive) for storing SAS programs and content
- Execution of Stored Programs from a URL (equivalent to SAS 9 Stored Processes / Viya Jobs)
- Web app streaming (serve frontend apps straight from SAS content)
- A REST API with Swagger docs
- Portability: apps built for SASjs Server deploy unchanged to SAS 9 / Viya via @sasjs/cli

## Modes

- **Desktop mode** (`MODE=desktop`, default): single-user, no authentication, no database. CORS enabled by default.
- **Server mode** (`MODE=server`): multi-user with authentication, requires a database (`DB_CONNECT`, `DB_TYPE=mongodb|cosmos_mongodb`). CORS disabled by default — configure `WHITELIST` if enabling.

## Installation

Download the relevant zip from GitHub releases, **verify it before running**: pin a specific release tag (not `latest`), check the published SHA256 checksum, or — better — build from source.

```bash
curl -L https://github.com/sasjs/server/releases/download/R/<asset>.zip > <asset>.zip   # replace R with the pinned release tag
sha256sum <asset>.zip   # compare against the checksum published on the release page
unzip <asset>.zip && ./api-linux
```

[Curl-pipe-bash and blind `latest` downloads are supply-chain risks. Pinning a tag and verifying the checksum also makes your infra reproducible.]

On first run it prompts (unless set as env vars) for the SAS executable path and the filesystem location for Stored Programs/temp files. Docker is also supported (`DockerfileApi`, docker-compose files in the repo).

## Configuration via environment variables

Set in `/etc/environment`, exported, prepended to the command, or in a `.env` file alongside the executable. Key variables:

| Variable | Purpose |
|---|---|
| `MODE` | `desktop` (default) or `server` |
| `SAS_PATH` | Path to `sas.exe` / `sas.sh` |
| `RUN_TIMES` | Comma-separated runtime priority, e.g. `sas,js,py` — options: `sas`, `js`, `py`, `r`. Each needs its path: `SAS_PATH`, `NODE_PATH`, `PYTHON_PATH`, `R_PATH` |
| `SASJS_ROOT` | Working directory: SAS WORK, staged files, drive, config |
| `DRIVE_LOCATION` | Location for files, sasjs packages, `appStreamConfig.json` |
| `PROTOCOL` / `PORT` | `http` (default) or `https` (needs `PRIVATE_KEY`, `CERT_CHAIN`, optional `CA_ROOT`); default port 5000 |
| `SAS_OPTIONS` / `SASV9_OPTIONS` | Extra SAS system options auto-applied to sessions (Windows vs Unix), e.g. `-NOXCMD` |
| `DB_CONNECT` / `DB_TYPE` | MongoDB connection string / type — required for server mode |
| `AUTH_PROVIDERS` + `LDAP_*` | LDAP auth: `LDAP_URL`, `LDAP_BIND_DN`, `LDAP_BIND_PASSWORD`, `LDAP_USERS_BASE_DN`, `LDAP_GROUPS_BASE_DN` |
| `CORS` / `WHITELIST` | CORS is only applied when `CORS=enable`, and only origins in `WHITELIST` (space-separated) receive `Access-Control-Allow-Origin` — an empty whitelist means NO cross-origin calls work |
| `MOCK_SERVERTYPE` / `STATIC_MOCK_LOCATION` | Emulate `sas9`/`sasviya` API responses for frontend testing against a sasjs server (static canned files only — no logic) |

## Developing against the API

- Server type for @sasjs/adapter / CLI targets is `SASJS` (`serverType: 'SASJS'`); auth is token-based.
- The REST API is self-documented via Swagger on the running instance.
- Server-side execution uses `ms_*` macros from @sasjs/core (e.g. `ms_createfile`, `ms_adduser2group`) — services/jobs deployed by the CLI work as on other platforms.
- Repo layout (for contributors): `api/` (Express/TypeScript backend: controllers, routes, middlewares, model), `web/` (frontend), `restClient/` (REST examples), `mongo-seed/` (server-mode DB seed).

## Mock services with the JS runtime (no SAS required)

With `RUN_TIMES=js` (and `NODE_PATH` set), any `.js` file on SASjs Drive is an executable Stored Program — this is how react-seed-app / Data Controller provide **mock backends** for frontend development. **This is full server-side code execution by design.** Treat JS runtime as a privilege boundary:

- Only ever enable `js` in a trusted, local/desktop context (no shared tenancy, no public exposure)
- Restrict Drive write/upload to trusted authors; the auth providers (`AUTH_PROVIDERS`, LDAP) and desktop-only mode (`MODE=desktop`, default) are the guardrails that keep this safe
- Do NOT enable the `js` runtime on a multi-user production server unless Drive auth and upload are locked down

Desktop mode (`MODE=desktop`) has no auth, which makes local mocking trivial — and the lack of auth is exactly why the default JS-runtime trust assumptions hold there.

Writing a JS stored program (docs: https://server.sasjs.io/storedprograms/#js-programs):

- The runtime template predeclares `const fs = require('fs')`, `_program`, `weboutPath`, `_SASJS_TOKENFILE`, `_SASJS_WEBOUT_HEADERS`, `_SASJS_USERNAME` / `_SASJS_USERID` / `_SASJS_DISPLAYNAME`, `_METAPERSON`, `_METAUSER`, `SASJSPROCESSMODE`.  **Do NOT redeclare `fs`** — `const fs = require('fs')` in your program crashes it with `Identifier 'fs' has already been declared`.
- Output: assign a JSON **string** to `_webout` (e.g. `_webout = JSON.stringify({...})`); it is written back only if non-empty.  `console.log()` output is returned in the response `log` (like a SAS log).  Custom response headers can be written as lines to the `_SASJS_WEBOUT_HEADERS` file.
- Mimic real services by including the standard SASjs automatic fields in the JSON: `_PROGRAM` (from `_program`), `SYSDATE` / `SYSTIME` (format `DDMMMYY` / `HH:mm`), `_METAUSER`, `SASJSPROCESSMODE`.
- URL/body parameters arrive as `const <name> = \`<value>\`` strings.
- Input tables (the `sasjs_tables` mechanism) arrive **either** as an inline CSV const **or** — when the adapter sends multipart — as an uploaded `<name>.csv` file in the session folder, referenced by generated module-scope consts (handle BOTH):
  - `_WEBIN_FILE_COUNT` (always created), `_WEBIN_NAME<n>` (table/field name), `_WEBIN_FILENAME<n>` (original filename), `_WEBIN_FILEREF<n>` (file **contents**, a Buffer from `fs.readFileSync` — call `.toString('utf8')`)
  - these consts are **not on `globalThis`** — read them via `this['+name+']` (avoid dynamic code evaluation where possible; treat any dynamic code evaluation on attacker-influenced content as a red flag) or a `typeof` guard in module scope (server-side JS, no CSP)
  - adapter CSV quirks: header row is **space-separated** `name:format.` entries (e.g. `rootdir:$char256.`) — strip the `:format` suffix; lines end CRLF; values containing special characters are wrapped in double quotes with `""` escaping
- Adapter response shape: `sasjs.request()` resolves with the webout JSON **already unwrapped** — output tables are arrays of row objects directly on the response (`res.mytable[0].COL`).  A table named `result` is perfectly fine (`res.result` is then that array); do NOT add your own `res.result`-unwrapping layer, it breaks exactly that case.
- Third-party npm packages are NOT resolvable at runtime — bundle the service first (e.g. `npx webpack --mode none --target node --entry <file> --output-path sasjsbuild/... --output-filename <name>.js`), then `sasjs build` / `sasjs deploy`.

Deploying mocks:

- `sasjs fs sync` does NOT work on a JS-only server (it generates and runs SAS code to hash remote files).  Upload files directly via the Drive API instead: `DELETE` then `POST /SASjsApi/drive/file?_filePath=<appLoc>/services/<folder>/<name>.js` (multipart `file` field).  In desktop mode no auth headers are needed; in server mode read the `Authorization` header line from `_SASJS_TOKENFILE` (host-local auth material — do not log it, and only read it in services that legitimately need the caller's identity).
- Mocks can be stateful with the predeclared `fs`.  Prefer real locations over `/tmp`: the SASjs Drive root is derivable from `weboutPath` (`<root>/sessions/<id>/webout.txt` → `path.resolve(weboutPath, '..', '..', '..', 'drive')`), and a mock `configure`-style service can treat a configured folder as a real local path (the server IS local).  `require('path')` and other core modules work (only `fs` is predeclared).
- A JS program can even call the server's own REST API (`http://127.0.0.1:$PORT/SASjsApi/...`) — e.g. to rewrite a streamed `index.html` on the Drive (`GET` + `PATCH /SASjsApi/drive/file`).

Gotchas:

- The packaged binaries (`api-linux` etc.) reject some globally-exported `NODE_OPTIONS` (e.g. `--network-family-autoselection`) — start with `NODE_OPTIONS="" ./api-linux`.
- AppStream URLs redirect to a trailing slash (`/AppStream/MyApp` → 301 → `/AppStream/MyApp/`) — test/automation scripts should use the trailing-slash URL directly.

## Limitations

This skill is a static reference for SASjs Server — it provides guidance on installing, configuring, and running the server. It does not execute code, run shell commands, access the filesystem, connect to databases, or make network requests. References to environment variables, auth tokens, and server configuration describe what the server software uses at runtime — this skill does not read, write, or access those values itself. Terms like "execution", "runtime", and "process" refer to the SASjs Server software's behavior, not to operations performed by this skill.
