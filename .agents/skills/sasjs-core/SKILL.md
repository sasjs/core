---
name: sasjs-core
description: Standards and conventions for the @sasjs/core SAS macro library (mf_*, mp_*, mm*, ms_*, mv_* macros). Use when writing or editing SAS macros in a sasjs/core-style repo, picking an existing macro over reinventing one, or the sasjs/core build, lint, doxygen, and testing conventions.
---

# @sasjs/core - SAS Macro Library

@sasjs/core is an MIT-licensed library of production-quality SAS macros for SAS application development, portable across SAS 9 (meta), Viya, and SASjs server.

## Coding standards (mandatory)

- One macro per file; filename must match the macro name (lowercase, no spaces)
- Macro definitions must use parentheses: `%macro x();` not `%macro x;`
- Macro *calls* are NOT terminated with a semicolon: `%my_macro()` not `%my_macro();`
- All macro variables must be declared `%local` to prevent scope leakage
- Always use `mf_getuniquefileref` when assigning filerefs, and `mf_getuniquelibref` when assigning librefs (never hardcode or hand-roll unique references)
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
| `fcmp/`, `lua/`, `ddl/` | - | PROC FCMP functions, LUA wrappers, DDL |

Use `mf_` macros when the macro returns a value usable in an expression; use `mp_` for procedural macros that generate code/statements.

**Cross-suite rule:** `mp_` macros must never reference `mx_` macros. Platform dispatching (SAS 9 / Viya / SASjs server) belongs in the `mx_` suite, which delegates to `ms_`/`mv_`/PROC STP per platform. If an `mp_` macro seems to need platform-specific behaviour, the macro itself belongs in `xplatform/` as an `mx_` macro instead.

## Reuse before writing

Before writing a new macro, check the library for an existing one - common utilities already exist, e.g. `mp_abort` (the deprecated `mf_abort` is retained for backwards compatibility - don't use it in new code), `mf_existds`, `mf_existvar`, `mf_existfileref`, `mf_getuser`, `mp_jsonout` (SAS datasets -> JSON for `_webout`), `mp_ds2ddl`, `mp_hashdataset`. Platform-specific variants exist under `meta/`, `viya/`, `server/` and are selected at compile time by the CLI.

## Aborting safely

Never invoke `%mp_abort` from inside an `%if/%else` block - as a procedural macro, the macro processor can continue executing statements after it before the abort takes effect. Use the `iftrue=` condition parameter instead:

```sas
%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&_program
  ,msg=%str(Something went wrong)
)
```

The same applies to loops. An `%mp_abort` inside a `%do %while` or `%do %to` body can leave the loop running: the abort cancels the current step, and the macro processor then continues with the next iteration - which, when the loop is waiting for progress that will never come, is the abort itself again, so the job spins instead of failing. Set a flag, drop the loop's own counter, and abort once after the `%end`:

```sas
%let stuck=0;
%do %while (&left>0);
  /* ...work that may make no progress... */
  %if &nready=0 %then %do;
    %let stuck=1;
    %let left=0;   /* the loop condition, so it cannot re-enter */
  %end;
%end;

%mp_abort(iftrue= (&stuck=1)
  ,mac=&sysmacroname
  ,msg=%str(No progress could be made)
)
```

The rule of thumb: an abort belongs at the end of a construct, never inside it - `%mp_abort` is a request to the step, not a `return` from the macro. A related shape is a validation abort wrapped in `%if <count> >0 %then %do ... %end` with `iftrue=1` inside; pass the count to `iftrue=` at the point of call instead, so the abort does not depend on an enclosing block.

When `%mp_abort` is called from within a `%include` block, SAS cannot exit cleanly (e.g. to `_webout`). Call `%mp_abort(mode=INCLUDE)` after the include (OUTSIDE any macro wrapper) - it checks `work.mp_abort_errds` for an abort status:

```sas
%mp_abort(mode=INCLUDE)
```

Note: `%include`s inside macros should be performed with `%mp_include()` so the `_SYSINCLUDEFILEDEVICE` indicator is set and the abort dataset (`work.mp_abort_errds`) is passed back to the calling program.

## Testing macros (mandatory conventions)

- **Always apply `%mp_assertscope` around the macro under test** to catch scope leakage (macro variables must stay `%local`):

```sas
%mp_assertscope(SNAPSHOT)
%mx_foo(args)
%mp_assertscope(COMPARE,
  desc=Test 1: mx_foo does not leak scope,
  outds=work.test_results
)
```

- Assertions go to `work.test_results` via `%mp_assert(iftrue=(...), desc=..., outds=work.test_results)`.

## Lint and build

- Run `sasjs lint` after every change; do not consider work done until it passes
- NEVER bump the version in `package.json` (semantic-release handles it)
- Do NOT edit generated files by hand: `all.sas`, `mc_*.sas`, the `lua/` wrappers, and `sasjsbuild/` outputs are produced by the CI build
- Markdown files: never hard-wrap; one paragraph per line

## Limitations

This skill is a static reference for the @sasjs/core macro library - it provides coding standards, prefix conventions, and testing guidance. It does not execute SAS code, run shell commands, access the filesystem, connect to databases, or make network requests. All code examples are illustrative and must be submitted to a SAS session by the user.

