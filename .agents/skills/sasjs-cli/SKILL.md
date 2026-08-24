---
name: sasjs-cli
description: Using the SASjs CLI (@sasjs/cli) to create, compile, build, deploy, run, and test SASjs projects against SAS 9, Viya, and SASjs server targets. Use for any `sasjs <command>` usage, CI/CD pipelines, target/auth config, sasjsconfig.json, service packs, or frontend streaming builds.
---

# @sasjs/cli

The SASjs CLI (`npm i -g @sasjs/cli`, invoked as `sasjs`) automates compiling, building, and deploying SAS projects. All commands support `-t <target>` to select a target from `sasjsconfig.json`.

## Targets and auth

- A **target** = `{ name, serverUrl, serverType, appLoc }`. `serverType` is one of `SAS9`, `SASVIYA`, `SASJS`.
- Credentials: `sasjs add cred` (or `.env` file). Viya uses client/secret **or** `sasjs auth login` (user/pass, no client/secret needed — see below); SAS 9 uses user/pass; SASJS server uses an access token.
- `sasjs context` manages Viya compute contexts; `sasjs add target` adds a new target.

## Core workflow

```
sasjs create myapp        # scaffold a new app (templates available)
sasjs compile             # gather macros/services/jobs into per-file build outputs (sasjsbuild/)
sasjs build               # produce deployable artefacts: JSON + .sas per target
sasjs deploy              # deploy compiled/built artefacts to the target server
sasjs cbd                 # compile + build + deploy in one step (-t viya etc.)
```

## Command reference

| Command | Purpose |
|---|---|
| `sasjs create / init` | Scaffold new app or add SASjs to existing repo |
| `sasjs compile` | Resolve dependencies (`<h4> SAS Macros </h4>` etc.) into `sasjsbuild/` |
| `sasjs build` | Create build JSON / service pack per target |
| `sasjs deploy` / `cbd` | Deploy to server (servicepack or direct) |
| `sasjs run <file.sas>` | Execute an arbitrary SAS file on the server, return log |
| `sasjs request <path>` | Execute a deployed service/job with input data (`-d`) |
| `sasjs job execute` | Run a deployed job |
| `sasjs flow execute` | Run a sequence of jobs with dependencies (CSV-defined flows) |
| `sasjs servicepack deploy` | Deploy from a JSON service pack |
| `sasjs web` | Build the frontend and stream it into the SAS web root (streamConfig) |
| `sasjs db` | Build database DDL/data load scripts from `sasjs/db` |
| `sasjs doc` | Generate doxygen documentation + lineage |
| `sasjs folder create/delete/move` | Manage folders in SAS metadata / SAS Drive |
| `sasjs fs` | File-system operations against the server (sync folders) |
| `sasjs test` | Execute tests defined in `sasjs/tests` with init/term programs |
| `sasjs lint` | Lint `.sas` files per `.sasjslint` config |
| `sasjs version` | Print/set version info |

## Conventions

- Test coverage is generated only from a `sasjs compile` (or `sasjs c`). It accepts a target (`-t <target>`), but nothing is deployed to that target — compilation and coverage are fully local/offline, so no server needs to be available or reachable. Missing macro dependencies (e.g. `mp_ds2csv.sas`) mean `@sasjs/core` isn't installed — run `npm i` first.

- Dependencies are declared in doxygen headers: `<h4> SAS Macros </h4>`, `<h4> SAS Files </h4>`, `<h4> SAS Folders </h4>`, and `@li item` entries — the CLI builds the dependency tree from these.
- `sasjs compile` output goes to the `sasjsbuild/` folder (git-ignore it); `sasjsresults/` holds test/run outputs.
- CI/CD: `sasjs cbd -t viya` is the standard deploy step; combine with `sasjs servicepack deploy` for artefact-based releases.
- Exit codes are non-zero on failure — safe for pipelines.

## Gotchas

- Run `npm i` before `sasjs cb` — macro dependency resolution needs `node_modules/@sasjs/core` present, and `@sasjs/core` (and `@sasjs/adapter` if used) must be listed in `package.json`.
- Credentials files are per-target: `.env.<targetname>` (e.g. `.env.server`) with `CLIENT`, `ACCESS_TOKEN`, `REFRESH_TOKEN`. Never commit them — gitignore `.env*`.

## Viya auth without a client/secret (`sasjs auth login`)

`sasjs auth login -t <target>` authenticates with a regular SAS username/password via the OAuth2 password grant against the built-in, secret-less `sas.cli` public client. No admin-registered OAuth client is needed — the fastest way to get `sasjs run`/`deploy` working on dev/demo estates. The password is never stored; the minted ACCESS_TOKEN/REFRESH_TOKEN pair is persisted to `.env.<target>` (local) or `~/.sasjsrc` (global) and verified via `/identities/users/@currentUser` (`Logged in as <id> (<name>)`). Bare `sasjs auth` is still an alias for `sasjs add cred`.

- Token expiry: the CLI silently refreshes via the stored refresh token (works with and without a client/secret), and re-persists the rotated pair — Viya refresh tokens are **single-use/rotating**, so this persistence is what keeps later invocations working. If refresh fails, re-run `sasjs auth login`.
- Some estates give `sas.cli` a short access-token TTL (e.g. 1h); a refresh on most invocations is normal.
- Opaque (non-JWT) tokens are treated as usable — the server is the authority on expiry.
- Limitations: local/LDAP accounts only (no SSO/SAML/MFA estates); password grant must be enabled for `sas.cli` (default on Viya 3.5+/4); ROPC is deprecated in OAuth 2.1 — use a registered client/secret for CI/production.
- `sasjs run` 403 on session creation = the account isn't authorised for the configured compute context — set `contextName: "SAS Studio compute context"` on the target. First run on a cold estate can take many minutes (compute pod spin-up) and may appear to hang.
- Self-signed estates: use `--insecure` on `auth login`, or configure `httpsAgentOptions` on the target.

## Viya streaming apps (streamConfig.streamWeb)

With `streamWeb: true`, `sasjs web`/`cbd -t viya` deploys the frontend **into SAS Files Service**: a streaming job at `<appLoc>/services/<streamServiceName>.html` serves `index.html`, and assets land in `<appLoc>/services/web/...`. At build time every asset/script/css URL in the HTML is rewritten to `/SASJobExecution?_FILE=<appLoc>/services/web/...` and the adapter config element (`<sasjs apploc=...>`) is stamped with the target `appLoc`.

**Consequence: the app only works when served from the exact `appLoc` it was deployed against.** If the streaming HTML is placed anywhere else (e.g. manually uploaded to a user home folder like `/Users/<id>/myapp/...`), all rewritten `/Public/app/...` asset links 404 and the adapter calls the wrong service paths — the page renders with no CSS/JS and no backend. Fix by redeploying.  The original build (`sasjs cb`) has the apploc from the sasjsconfig.json - when the app is deployed as a SAS program, the supplied `%let apploc = ` (runtime value) is swapped with the `compiled_apploc` (build time value) to allow apps to be dynamically deployed to a given apploc at deploy time.

### Verifying a Viya deployment headlessly (no browser)

1. Get a token (password grant works out of the box with the built-in `sas.ec` client, empty secret):
   `curl -X POST <server>/SASLogon/oauth/token -u 'sas.ec:' -d 'grant_type=password&username=U&password=P'`
2. Fetch the app: `GET /SASJobExecution/?_FILE=<appLoc>/services/<name>.html` with `Authorization: Bearer` → expect `200` and the full `index.html`. `401` = auth, anything else = not deployed there.
3. Fetch each asset the HTML references. Response tells you what's wrong:
   - `200` with file content → asset deployed correctly.
   - `202` + a tiny plain-text body (e.g. `Parameter Error\nFile error`) → **file does not exist at that Drive path** (classic appLoc-mismatch symptom). Note `_FILE` responses can be async: add `&_action=wait` to get content synchronously.
   - Services: `POST /SASJobExecution/?_program=<appLoc>/services/<svc>&_action=wait` → `Parameter Error / Unable to get job definition` means the service was never deployed as a JES job (files on Drive alone are not enough — only `sasjs deploy`/`cbd`/`servicepack deploy` registers them).

### Talking to SAS — ALWAYS use the adapter or the CLI

When executing a SAS service or job for any purpose (debugging, reproduction, CI), **always go through the `@sasjs/adapter` or `sasjs` CLI** — never hand-roll curl against `SASJobExecution`. The adapter and CLI handle the things that are trivial to get wrong by hand: the input-data CSV format (space-separated `name:$format.` headers, CRLF, double-quoted special values, `%nrstr(...)` wrapping), the execution-mode routing (`_executionTasks=true` reads `sasjs<N>data` as **macro variables**, not file uploads), the `_debug`/`>>weboutBEGIN<<`/`>>weboutEND<<` wrapper parsing, the token refresh, and the `_contextname` URL param. A hand-built comma-separated CSV will read as blanks, silently skip guarded macro blocks, and send you down a rabbit hole of phantom bugs.

- Build input data as a JSON file: `{ "<table>": [{ "<col>": "<val>", ... }] }`, e.g. `{ "config": [{ "rootdir": "/export/...", "runastask": "true", "usecomputeapi": "null", "contextname": "Compute Reusable" }] }`.
- Run: `sasjs request '<appLoc>/services/common/<svc>' -t viya -d data.json -l <path>.log -o <path>.json`. The CLI hardcodes `debug: true`, so the `-l` flag always captures the full MPRINT/NOTE/`&syscc` log; `-o` saves the parsed webout. **Always pass `-l`** — reproducing a bug without the log means re-running the whole thing.
- The Viya Folders/JES REST APIs ARE fine to hit directly with curl (token + `Authorization: Bearer`) for folder/file/member management and for `GET /SASJobExecution/?_FILE=...` asset checks — just not for *executing your own services with input data*.

#### Adapter execution-context and input-data facts

- The adapter automatically appends `_contextname=<value>` as a **URL parameter** to every Viya JES request (you do NOT need to pass it yourself). BUT JES request params are **NOT auto-promoted to SAS macro variables** — `%symexist(_contextname)` is false inside the service. If the service needs the chosen context name (e.g. to stamp it into the streamed HTML), pass it in the **input data table** (a `contextname` column) and read it with `call symputx` — that is the reliable channel.
- The target's `contextName` in `sasjsconfig.json` decides which compute context the service runs under (and thus the `runAs` identity). The adapter's URL `_contextname` param is the same value. To reproduce a service under a batch/reusable context via `sasjs request`, set the target's `contextName` to that reusable context (e.g. `Compute Reusable`, runAs=sasbatch) — otherwise it runs as your own identity and write-test steps to batch-owned folders fail with `User does not have appropriate authorization level`.
- Adapter CSV format (so you can read the `NOTE: The infile ... is:` RULE in the log correctly): row 1 is the header with `name:$informat.` pairs **space-separated**; data rows are **comma-separated** (CRLF), with values double-quoted only if they contain a special char (`,`, `"`, tab, newline). The sasjs/core webout reader reads it back with `dsd` + `firstobs=2` + an `input <name>:$informat.;` statement derived from the header.
- `_executionTasks=true` (runAsTask) changes how input data arrives: as `sasjs<N>data` **macro variables** (chunked into `sasjs<N>data0..N`), NOT as `_WEBIN_FILE` uploads. The core webout `mv_webout` macro handles both, but it branches on `_EXECUTIONTASKS` — be aware when reading logs.

### Redeploying cleanly on Viya (the 409 Conflict problem)

Re-running `sasjs cbd`/`sasjs run viya.sas` against an **existing** appLoc often fails mid-deploy with `409 Conflict` (and an `mp_abort` → `abort cancel`): `mv_createfile` DELETEs the old file id then tries to recreate it, but when an intermediate **folder** already exists (e.g. `<appLoc>/services/web/js`) the recreate step conflicts and the whole deploy aborts — leaving a half-deployed app (services present, some assets missing). The `?recursive=true` folder DELETE also returns `409 You cannot delete the folder because it is not empty`, and individual member/folder DELETEs can return `403` even as the owner, so you cannot easily tear the tree down by hand.

The reliable workaround is to **move the top appLoc folder out of the way** and redeploy to the original path — the deploy creates a fresh folder tree with no conflicts, and the old folder is retained as a backup. This is far faster and more reliable than fighting per-member deletes, and is the recommended pre-deploy step for any non-CI redeploy on Viya. Two ways to move it:

- **Rename in place** (simplest): `PATCH /folders/folders/{id}` with `{"name":"<old>.bak.<ts>","version":2}` — frees the original name, keeps the old folder as a sibling backup.
- **MOVE into a backup parent** (tidier — keeps all backups in one place): create (once) a backup parent folder e.g. `/Users/<id>/macrodash-backups`, then `POST /folders/folders/{backupParentId}/members/{appLocFolderId}?action=move` moves the whole tree (with contents) into it, freeing the original path for the fresh deploy.

(On sasjs/server just `sasjs fs delete` the appLoc first — Drive there supports clean recursive deletes.)

JES applies its own CSP header when streaming (includes `unsafe-inline`/`unsafe-eval`); a strict CSP meta tag in the app's HTML still applies and is the one that matters for the app code.
