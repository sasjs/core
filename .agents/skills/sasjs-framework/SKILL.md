---
name: sasjs-framework
description: Building full SASjs applications — project structure, sasjsconfig.json, services/jobs/macros folders, multi-target (SAS 9 / Viya / SASjs server) configuration, streaming frontends, mocks and tests. Use when creating or modifying a SASjs app, editing sasjsconfig.json, or writing backend services returning JSON to a web frontend.
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

## Streamed frontend files on Viya (mime types)

When `streamWeb: true`, the CLI uploads the frontend (`index.html`, renamed per `streamServiceName`, plus css/js) to the Viya Files service using the `%mv_createfile` macro. That macro creates the file in a very particular way to ensure it streams correctly:

- POSTs to `/files/files` with the content type derived from the extension (`%mf_mimetype`)
- sets `typeDefName=file_html` (via `%mv_getViyaFileExtParms`) so the file is recognised as HTML
- sends `Content-Disposition` **without** `attachment` for HTML/SVG so it renders in the browser

**Never update a streamed frontend file in place** with a `filename filesrvc` fileref + data step rewrite — the Files service then treats it as a generic blob and the mime type is lost, so the app no longer streams (browser downloads it or shows raw text). To modify a streamed file at runtime (eg patching the compute `contextname` in the html), read it (a `filesrvc` fileref is fine for *reading*), write the modified content to a temp fileref, and **re-create the file with `%mv_createfile(path=..., name=..., inref=...)`** (it deletes the old file and re-POSTs with the correct mime type).

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

## Sanitising service inputs (SAS macro injection)

Every value arriving from the web request (input tables, url params) is attacker-controlled. If it is resolved as a macro variable inside generated code — a `libname` path, a `set`/`from` statement, a `where` clause, a `%include` — then spaces, quotes, semicolons and `&`/`%` macro triggers become classic SAS injection vectors.

Rules:

- Validate inputs in a data step with `%mp_validatecol(incol,RULE,outcol)` from @sasjs/core **before** any `call symputx`. Only symput on pass; abort otherwise (`%mp_abort(iftrue=...)`). Rules include `ISLIB` (valid libref), `ISNAME` (valid SAS name, eg a member/table name), `LIBDS` (`LIBREF.DATASET`), `FORMAT`, `ISINT`, `ISNUM`.
- Where a whitelist exists, use it: after syntactic validation, confirm the value exists in a control table (eg a primary-key lookup) before using it to build paths or code.
- Values read back from control tables can also be tampered with — validate those too before passing them into code-generating macros.
- For free-text values that must be echoed into code (eg a user message), strip macro triggers: `compress(value,'&%;')` or `tranwrd` each dangerous char — but prefer not to place free text in code at all.

```sas
%let libds=0;
data _null_;
  set work.sascontroltable;
  %mp_validatecol(libds,LIBDS,is_libds)
  if is_libds=1 then call symputx('libds',libds);
  else putlog 'ERR' 'OR: invalid libds: ' libds;
run;
%mp_abort(iftrue= ("&libds"="0")
  ,mac=&_program
  ,msg=%str(Invalid libds provided)
)
```

## Multi-target discipline

- Keep backend code platform-neutral in shared folders; put platform-specific shims in `targets/<name>/macros_*` folders and register them only on that target.
- Platform capability macros exist in @sasjs/core (`mm_*` metadata, `mv_*` Viya, `ms_*` server) — don't branch on server type by hand.

## Quality gates (follow the conventions of mature apps like Data Controller)

- Run `sasjs lint` after touching any `.sas` file; fix all warnings in files you touched.
- The linter enforces 2-space indentation everywhere, including continuation lines inside `/* ... */` block comments — never align comment text with 3+ spaces.
- Add tests and run `sasjs test` for backend logic changes. When testing macros, always wrap the macro under test with `%mp_assertscope(SNAPSHOT)` / `%mp_assertscope(COMPARE, ...)` to catch macro-variable scope leakage, and wrap any platform-branching code in `%macro` wrappers (no open conditional macro code in test programs).
- Provide mocks in `sasjs/mocks` so the frontend can be developed without a live SAS server.
- Never auto-commit or bump versions; releases are pipeline-driven (conventional commits).
- Markdown files: no hard wrapping — one paragraph per line.
- Apps must work offline/on-prem: no external CDN assets in the frontend bundle.

## Tests must be idempotent

A test file must pass when run repeatedly (including after a run that failed partway).

- Start the file with `%let syscc=0;` — many DC macros abort on entry if `&syscc>0`, and any `WARNING` in a previous test bumps `syscc` to 4.
- Make prep defensive: delete-then-insert config records (handles leftovers from an aborted run),
  and recreate physical tables rather than assuming they are absent.

## Reference implementations

Look at existing apps for patterns: folder layouts, `sasjsconfig.json` multi-target setups, service structure, streaming builds, and test/mock conventions, eg:
* https://git.datacontroller.io/dc/dc
* https://github.com/sasjs/react-seed-app
* https://github.com/sasjs/macro-dash

## Limitations

This skill is a static reference for building SASjs applications — it provides guidance on project structure, configuration, and service contracts. It does not execute code, run shell commands, access the filesystem, connect to databases, or make network requests. References to file paths, build outputs, and deployment targets describe the structure of a SASjs project — this skill does not create, modify, or access those paths itself.