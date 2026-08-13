---
name: sasjs-framework
description: Building full SASjs applications — project structure, sasjsconfig.json, services/jobs/macros folders, multi-target (SAS 9 / Viya / SASjs server) configuration, streaming frontends, mocks and tests. Use when creating or modifying a SASjs app, editing sasjsconfig.json, writing backend services that return JSON to a web frontend, or structuring a project like Data Controller.
---

# SASjs Framework — Building SASjs Applications

A SASjs app = a web frontend (any framework: Angular, React, vanilla) + SAS backend code organised in a standard layout, compiled and deployed by `@sasjs/cli` to SAS 9, Viya, or SASjs server. Frontend talks to SAS via `@sasjs/adapter`; backend services return JSON via `_webout`.

## Standard project layout

```
sasjs/
  sasjsconfig.json     # project + target configuration
  macros/              # project-specific macros (macroFolders)
  services/            # web services called from the frontend
  jobs/                # jobs (scheduled / flow / long-running)
  programs/            # plain programs (initProgram, termProgram, utilities)
  db/                  # DDL + static data per library (sasjs db)
  tests/               # tests run by `sasjs test`
  mocks/               # mock responses for offline frontend dev (syncFolder)
  doxy/                # extra doxygen content for `sasjs doc`
```

## sasjsconfig.json

Root config holds defaults; each entry in `targets[]` can override them. Key sections:

- `macroFolders`, `binaryFolders` — where the CLI finds macros/binaries
- `serviceConfig.serviceFolders` — service source folders; `initProgram` runs before every service (set up libnames, options)
- `jobConfig.jobFolders` — job source folders
- `programFolders` — programs compiled/deployed with the app
- `streamConfig` — `streamWeb: true` streams the built frontend into SAS so it is served by the platform itself (no separate web server needed); `webSourcePath` points at the frontend build output
- `syncFolder` — folder synced to the server (e.g. mocks)
- `testConfig` — init/term programs for `sasjs test`
- `targets[]` — per-environment overrides: `serverUrl`, `serverType` (`SAS9`/`SASVIYA`/`SASJS`), `appLoc` (deploy root, e.g. `/Public/app/myapp`), target-specific macroFolders (e.g. `targets/viya/macros_viya` for platform shims), `httpsAgentOptions`, `deployConfig`

The full JSON schema is bundled at `sasjsconfig-schema.json` next to this file — validate config changes against it. Reference it with `"$schema": "https://cli.sasjs.io/sasjsconfig-schema.json"`.

## Service contract (frontend ↔ SAS)

1. Adapter POSTs to `services/<folder>/<name>` with input tables (arrays of objects) → work datasets named after the JS keys.
2. Service SAS code runs after `initProgram`; it reads inputs, does work, and writes output JSON to `_webout`.
3. Conventional pattern using @sasjs/core macros:

```sas
/**
  @file
  @brief Example service returning data
  <h4> SAS Macros </h4>
  @li mp_jsonout.sas
  @li mp_abort.sas
**/

/* validation / logic here */

%mp_jsonout(OPEN)
%mp_jsonout(OBJ,results,dslabel=results)
%mp_jsonout(CLOSE)
```

4. On error, abort cleanly with `%mp_abort(...)` (`mf_abort` is deprecated) so the adapter receives a structured error in the JSON, not a half-written response. Do **not** call `%mp_abort` inside an `%if/%else` block — the macro processor may keep executing beyond the abort. Use the conditional `iftrue=` parameter instead, e.g.:

```sas
%mp_abort(iftrue= (%mf_existds(work.results)=0)
  ,mac=&_program
  ,msg=%str(No results found)
)
```

If the abort happens inside a `%include` block, SAS cannot exit to `_webout` cleanly — after the include, call `%mp_abort(mode=INCLUDE)` (outside any macro wrapper), which checks `work.mp_abort_errds` for an abort status.

## Multi-target discipline

- Keep backend code platform-neutral in shared folders; put platform-specific shims in `targets/<name>/macros_*` folders and register them only on that target.
- Platform capability macros exist in @sasjs/core (`mm_*` metadata, `mv_*` Viya, `ms_*` server) — don't branch on server type by hand.

## Quality gates (follow the conventions of mature apps like Data Controller)

- Run `sasjs lint` after touching any `.sas` file; fix all warnings in files you touched.
- The linter enforces 2-space indentation everywhere, including continuation lines inside `/* ... */` block comments — never align comment text with 3+ spaces.
- Add tests under `sasjs/tests` and run `sasjs test` for backend logic changes.
- Provide mocks in `sasjs/mocks` so the frontend can be developed without a live SAS server.
- Never auto-commit or bump versions; releases are pipeline-driven (conventional commits).
- Markdown files: no hard wrapping — one paragraph per line.
- Apps must work offline/on-prem: no external CDN assets in the frontend bundle.

## Reference implementations

Look at existing apps for patterns: folder layouts, `sasjsconfig.json` multi-target setups, service structure, streaming builds, and test/mock conventions (e.g. Data Controller `dc`, `dwp_frs`, `plato`).
