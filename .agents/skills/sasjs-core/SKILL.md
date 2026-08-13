---
name: sasjs-core
description: Standards and conventions for the @sasjs/core SAS macro library (mf_*, mp_*, mm*, ms_*, mv_* macros). Use when writing or editing SAS macros in a sasjs/core-style repo, when choosing an existing macro instead of reinventing one, or when asked about the sasjs/core build, lint, doxygen header, or testing conventions.
---

# @sasjs/core — SAS Macro Library

@sasjs/core is an MIT-licensed library of production-quality SAS macros for SAS application development, portable across SAS 9 (meta), Viya, and SASjs server.

## Coding standards (mandatory)

- One macro per file; filename must match the macro name (lowercase, no spaces)
- Macro definitions must use parentheses: `%macro x();` not `%macro x;`
- Macro *calls* are NOT terminated with a semicolon: `%my_macro()` not `%my_macro();`
- All macro variables must be declared `%local` to prevent scope leakage
- 2-space indentation, no tabs, no trailing spaces, no invisible characters, max line length 300 (hard lint limit) but keep lines to 80 chars max where possible
- Every file must have a Doxygen header:

```sas
/**
  @file
  @brief One-line description of the macro

  <h4> SAS Macros </h4>
  @li mf_othermacro.sas

  @param [in] paramname Description
  @param [out] outparam Description

  <h4> Related Macros </h4>
  @li mp_related.sas

  @version 9.4
  @author Your Name
**/
```

## Folder / prefix conventions

| Folder | Prefix | Platform |
|---|---|---|
| `base/` | `mf_` (function-style), `mp_` (procedure-style) | All platforms |
| `meta/` | `mm_` | SAS 9 metadata |
| `metax/` | `mmx_` | SAS 9 metadata (OS command dependent) |
| `viya/` | `mv_` | Viya |
| `server/` | `ms_` | SASjs server |
| `xplatform/` | `mx_` | Runtime platform detection |
| `fcmp/`, `lua/`, `ddl/` | — | PROC FCMP functions, LUA wrappers, DDL |

Use `mf_` macros when the macro returns a value usable in an expression; use `mp_` for procedural macros that generate code/statements.

## Reuse before writing

Before writing a new macro, check the library for an existing one — common utilities already exist, e.g. `mp_abort` (the deprecated `mf_abort` is retained for backwards compatibility — don't use it in new code), `mf_existds`, `mf_existvar`, `mf_existfileref`, `mf_getuser`, `mp_jsonout` (SAS datasets → JSON for `_webout`), `mp_ds2ddl`, `mp_hashdataset`. Platform-specific variants exist under `meta/`, `viya/`, `server/` and are selected at compile time by the CLI.

## Aborting safely

Never invoke `%mp_abort` from inside an `%if/%else` block — as a procedural macro, the macro processor can continue executing statements after it before the abort takes effect. Use the `iftrue=` condition parameter instead:

```sas
%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&_program
  ,msg=%str(Something went wrong)
)
```

When `%mp_abort` is called from within a `%include` block, SAS cannot exit cleanly (e.g. to `_webout`). Call `%mp_abort(mode=INCLUDE)` after the include (OUTSIDE any macro wrapper) — it checks `work.mp_abort_errds` for an abort status:

```sas
%mp_abort(mode=INCLUDE)
```

Note: `%include`s inside macros should be performed with `%mp_include()` so the `_SYSINCLUDEFILEDEVICE` indicator is set and the abort dataset (`work.mp_abort_errds`) is passed back to the calling program.

## Lint and build

- Run `sasjs lint` after every change; do not consider work done until it passes
- NEVER bump the version in `package.json` (semantic-release handles it)
- Do NOT edit generated files by hand: `all.sas`, `mc_*.sas`, the `lua/` wrappers, and `sasjsbuild/` outputs are produced by the CI build
- Markdown files: never hard-wrap; one paragraph per line
