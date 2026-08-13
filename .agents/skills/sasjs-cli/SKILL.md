---
name: sasjs-cli
description: Using the @sasjs/cli command-line tool to create, compile, build, deploy, run, and test SASjs projects against SAS 9, Viya, and SASjs server targets. Use for any sasjs <command> usage, CI/CD deployment pipelines, target/auth configuration, sasjsconfig.json manipulation, service packs, or frontend streaming builds.
---

# @sasjs/cli

The SASjs CLI (`npm i -g @sasjs/cli`, invoked as `sasjs`) automates compiling, building, and deploying SAS projects. All commands support `-t <target>` to select a target from `sasjsconfig.json`.

## Targets and auth

- A **target** = `{ name, serverUrl, serverType, appLoc }`. `serverType` is one of `SAS9`, `SASVIYA`, `SASJS`.
- Credentials: `sasjs add cred` (or `.env` file). Viya uses client/secret; SAS 9 uses user/pass; SASJS server uses an access token.
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

- Dependencies are declared in doxygen headers: `<h4> SAS Macros </h4>`, `<h4> SAS Files </h4>`, `<h4> SAS Folders </h4>`, and `@li item` entries — the CLI builds the dependency tree from these.
- `sasjs compile` output goes to the `sasjsbuild/` folder (git-ignore it); `sasjsresults/` holds test/run outputs.
- CI/CD: `sasjs cbd -t viya` is the standard deploy step; combine with `sasjs servicepack deploy` for artefact-based releases.
- Exit codes are non-zero on failure — safe for pipelines.
