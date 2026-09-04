---
name: sas
description: Expert guidance for the SAS programming language — DATA step, PROC SQL, macro language, formats, ODS, and common procedures. Pure SAS syntax only, no SASjs-framework content. Use when writing, reviewing, or debugging .sas programs, or answering SAS language questions.
license: MIT
copyright: Copyright (c) SASjs
spdx-license-identifier: MIT
---

# SAS Language

<!-- SPDX-License-Identifier: MIT -->
<!-- Style rules derived from the @sasjs/core coding standards (https://github.com/sasjs/core), MIT licensed. -->

Write idiomatic, production-quality SAS code. This skill covers the SAS language itself, independent of any framework.

## Scope

- DATA step programming (SET/MERGE/BY, RETAIN, arrays, DO loops, hash objects, first./last. processing)
- PROC SQL (joins, subqueries, views, pass-through with CONNECT TO)
- Macro language (%macro/%mend, macro variables, %local/%global, conditional %IF logic, quoting functions %STR/%NRSTR/%BQUOTE, CALL SYMPUTX)
- Common PROCs: SORT, MEANS/SUMMARY, FREQ, TRANSPOSE, REPORT, PRINT, CONTENTS, DATASETS, FORMAT, IMPORT/EXPORT
- Formats and informats (user-defined via PROC FORMAT, picture formats)
- ODS output (HTML, PDF, RTF, Excel, OUTPUT destination)
- File I/O: LIBNAME, FILENAME, INFILE/INPUT, FILE/PUT

## Workflow

Apply this loop to every request that produces SAS code — new program, edit, or debug:

1. **Analyze the request.** Identify the input(s): datasets, columns, macro variables, platform (SAS 9 vs Viya). Note the desired output: a dataset, a report (ODS), a macro variable, a file. If the request is ambiguous, state your assumption and proceed.
2. **Draft the code.** Write the minimum correct program following the Style rules below. Use 2-level dataset names, explicit `length` for character variables, `%local` inside macros, and `quit;` for `proc sql`. Prefer `proc sort nodupkey` over hand-rolled dedup.
3. **Run it (or describe the run).** If a SAS session is available, submit and capture the log. If not, trace the code mentally against the Common pitfalls list — call out any step you could not verify.
4. **Inspect the log.** Treat any `WARNING:` or `ERROR:` as a defect to fix, not a note to ignore. Common culprits: uninitialized variables, implicit numeric→character conversion, truncation from implicit length=8, "no observations", unresolved macro references, read-only automatic macro variables. Superfluous `NOTE`s should also be trimmed where reasonable.
5. **Review against pitfalls.** Re-read the final code against the Common pitfalls list before returning it. Fix or annotate anything flagged.

**Inputs:** a request (natural language or a `.sas` file), optionally sample data or a log excerpt. **Outputs:** idiomatic SAS code (2-space indented, `run;`/`quit;` terminated) plus, when useful, a short note on any pitfall addressed or assumption made. **Verification:** the returned code passes a mental log-scan with zero WARNING/ERROR, and a real run (when available) produces a clean log.

## Non-negotiable: no WARNINGs

Generated SAS code must run cleanly — **zero WARNINGs (and zero ERRORs) in the log**. Treat every `WARNING:` as a defect: uninitialized variables, implicit type conversions, truncation notes that should be warnings, "no observations", unresolved macro references, etc. If a warning is truly unavoidable, suppress it deliberately (e.g. an explicit option) and comment why. Likewise avoid superfluous NOTEs where reasonable.

## Style rules

These follow the @sasjs/core coding standards — apply them to all SAS code:

- One statement per line; indentation = 2 spaces, no tabs, no trailing whitespace
- Consolidate multi-operand statements — `%local`/`%global`, `length`, `attrib`, `retain`, `array`, `format`/`informat`, `label`, `keep`/`drop`, `var`, `rename` — into a single statement listing all operands. Never split into duplicate statements (two `%local` lines, two `length` statements, etc.) just to stay under the line limit; if the line exceeds it, wrap to the next line — the statement ends at the semicolon, so continuation lines are free.
- Lines no longer than 80 characters; unix (LF) line endings; UTF-8
- Avoid non-ASCII / special characters entirely — maximum compatibility across SAS installations and encodings
- Always end steps with `run;`; for `proc sql` (and CAS-connected procs) `quit;` is essential to avoid `WARNING: You cannot disconnect or terminate session ...` on Viya
- All dataset references must be 2-level (`work.blah`, not `blah`) — protects against `DATASTMTCHK=ALLKEYWORDS` and an active `USER` library
- Explicit `length` / `attrib` for character variables rather than relying on defaults (avoids implicit length=8 truncation)
- Use literal suffixes for clarity (`'01JAN2020'd`, `'12:30't`)
- Prefer `proc sort` with `nodupkey` over manual dedup logic
- Macros:
  - Define with parentheses, even with no parameters: `%macro x();` not `%macro x;`
  - Closing `%mend;` must repeat the macro name
  - Macro calls are not terminated with a semicolon: `%my_macro()` not `%my_macro();`
  - Mandatory parameters positional; optional parameters keyword (`var=`) style
  - Macro names lowercase, verb-noun convention
  - Macro variables without trailing dot (`&var` not `&var.`) unless needed to prevent incorrect resolution
  - Macro variable NAMES are case-insensitive: `&Foo`, `&FOO`, and `&foo` all resolve to the same symbol (same for `%symexist`/`%superq`/`symget` arguments, which take a NAME not a value). Don't chase case mismatches as a bug — it's never the cause.
  - ALL macro variables must be `%local` unless deliberately global (globals should use an application prefix to avoid collisions); use `call symputx` (not `symput`) in DATA steps
  - Comment with `/* */` inside macros (asterisk comments are compiled into the macro)
  - Guard macro logic with `%length(&var)=0` checks rather than `&var=` (empty comparisons are unsafe)
- Avoid naming collisions: use `%sysfunc`-/`&syslast`-based work tables (e.g. `data &output; set &syslast; run;`) rather than hard-coded names
- WORK library is auto-cleared on session termination: SAS deletes every table in WORK when the session ends, so explicit cleanup (`proc datasets lib=work nolist; delete ...; quit;`) is not required for ordinary temporary tables — do not add it, and do not flag its absence as a defect in review. Clean up explicitly only when temp files are large or voluminous enough to risk disk pressure mid-run; in that case, drop them as soon as they are no longer needed rather than leaving them for end-of-session disposal.
- No open (non-macro) conditional code: wrap platform-branching or conditionally-executed blocks (e.g. `%if %mf_getplatform()=VIYA %then %do; ... %end;`) in a `%macro ... %mend` and invoke the macro. Open `%if` at program level fails in some execution contexts (job/scheduler/test harnesses) and hides scope leaks.

## Portability awareness

- Note when code differs between SAS 9.4 and Viya (e.g. CAS actions vs procs, `proc casutil` for sashdat loading, no X command on locked-down servers)
- Avoid hard-coded physical paths and engine-specific options unless asked
- No open macro code with if/else logic: wrap branching blocks in `%macro ... %mend` and call them — open `%if`/`%else` does not behave as expected in all SAS environments.

## Before / after examples

Each pair shows a common WARNING- or defect-prone pattern and the idiomatic fix, with the log issue it addresses.

### DATA step: uninitialized variable + implicit length truncation

Before — `region` is referenced but never assigned or brought in via `set`, so the log shows `WARNING: Variable region is uninitialized`; and `name` inherits the length of `first_name` from the source (often $8), silently truncating the concatenated value:

```sas
data work.customers;
  set work.source;
  region = upcase(region);                 /* region not in work.source */
  name = catx(' ', first_name, last_name); /* truncated to source length of name */
run;
```

After — `region` is brought in via `set` (or explicitly assigned), and an explicit `length` before `set` widens `name` so `catx` is not truncated:

```sas
data work.customers;
  length name $ 50;
  set work.source;                          /* region must exist in work.source */
  region = upcase(region);
  name = catx(' ', first_name, last_name);
run;
```

### PROC SQL: implicit conversion + cartesian product

Before — joining on character `id` vs numeric `cust_id` triggers `NOTE: Character values have been converted to numeric` (or a WARNING under some options), and the missing join key risks a cartesian blow-up:

```sas
proc sql;
  create table work.joined as
  select a.*, b.balance
  from work.orders a, work.accounts b
  where a.id = b.cust_id;
quit;
```

After — explicit `length`/cast so types match, explicit inner join, and a guard against the cartesian if keys are missing:

```sas
proc sql;
  create table work.joined as
  select a.id, a.amount, b.balance
  from work.orders as a
  inner join work.accounts as b
    on a.id = input(b.cust_id, 8.) /* explicit cast; or fix upstream length */
  ;
quit;
```

If a key column legitimately has duplicates on both sides, aggregate or dedup first — never rely on an accidental 1:1 join.

### Macro: missing `%local` + unsafe empty check

Before — `%let` inside the macro creates `dsid` in global scope (no `%local`), and `%if &filter=` is unsafe — when `&filter` is empty it resolves to `%if = %then`, a syntax error rather than a clean branch:

```sas
%macro apply_filter(filter=);
  %if &filter= %then %do;
    data work.out; set work.in; run;
  %end;
  %else %do;
    data work.out; set work.in; where &filter; run;
  %end;
  %let dsid = &syslast;
%mend apply_filter;
```

After — `%local dsid` keeps the temp variable in macro scope, `%length(&filter)=0` guards the empty check safely, parentheses on the macro definition, and `%mend` repeats the name:

```sas
%macro apply_filter(filter=);
  %local dsid;
  %if %length(&filter)=0 %then %do;
    data work.out; set work.in; run;
  %end;
  %else %do;
    data work.out; set work.in; where &filter; run;
  %end;
  %let dsid = &syslast;
%mend apply_filter;
```

### Multi-operand statements: one statement, not duplicates

Before — two `%local` statements and two `length` statements for related operands. This is needless repetition; the operands belong in a single declaration:

```sas
%local dbg libref1 libref2 loglocation fname1 fname2;
%local jobstate err_httpcode err_msg;

data work.staged;
  length customer_id 8;
  length customer_name $ 50;
  set work.source;
run;
```

After — consolidate each group into one statement; wrap to a continuation line when the single statement exceeds 80 chars (the statement ends at the semicolon, so wrapped lines are free):

```sas
%local dbg libref1 libref2 loglocation fname1 fname2
       jobstate err_httpcode err_msg;

data work.staged;
  length customer_id 8 customer_name $ 50;
  set work.source;
run;
```

This applies to every statement that accepts a list of operands — `%local`/`%global`, `length`, `attrib`, `retain`, `array`, `format`/`informat`, `label`, `keep`/`drop`, `var`, `rename`.

## Common pitfalls to flag when reviewing

- Unintended many-to-many MERGEs
- Automatic variable `_ERROR_` / implicit RETAIN surprises
- Macro timing issues: referencing `&macrovar` before it exists, `%if` evaluating data-step variables (use `if`/`symget` instead)
- Automatic macro variables (`&syscc`, `&syswarningtext`, `&syserrortext`, `&sysdate`, `&sysuserid`, etc.) are READ-ONLY — attempting to overwrite them (e.g. `%let syswarningtext=;` or `call symput('syscc',...)`) raises `ERROR: Unable to assign value to a macro variable that is read only` (or similar). Never try to "clear" them.
- Truncation from implicit length=8 on first assignment
- `proc sql` cartesian product warnings

## Limitations

This skill is a static language reference — it provides guidance for writing and reviewing SAS code. It does not execute SAS code, run shell commands, access the filesystem, connect to databases, or make network requests. All code examples are illustrative and must be submitted to a SAS session by the user. Terms like "File I/O", "PROC SQL", "command", and "execution" refer to SAS language concepts (file-handling statements, SQL procedure, macro execution contexts), not to operating-system-level operations performed by this skill.
