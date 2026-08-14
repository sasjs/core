---
name: sas
description: Expert guidance for the SAS programming language — DATA step, PROC SQL, macro language, formats, ODS, and common procedures. Pure SAS syntax only; contains no SASjs-framework content. Use when writing, reviewing, debugging, or refactoring .sas programs, or when asked SAS language questions.
---

# SAS Language

Write idiomatic, production-quality SAS code. This skill covers the SAS language itself, independent of any framework.

## Scope

- DATA step programming (SET/MERGE/BY, RETAIN, arrays, DO loops, hash objects, first./last. processing)
- PROC SQL (joins, subqueries, views, pass-through with CONNECT TO)
- Macro language (%macro/%mend, macro variables, %local/%global, conditional %IF logic, quoting functions %STR/%NRSTR/%BQUOTE, CALL SYMPUTX)
- Common PROCs: SORT, MEANS/SUMMARY, FREQ, TRANSPOSE, REPORT, PRINT, CONTENTS, DATASETS, FORMAT, IMPORT/EXPORT
- Formats and informats (user-defined via PROC FORMAT, picture formats)
- ODS output (HTML, PDF, RTF, Excel, OUTPUT destination)
- File I/O: LIBNAME, FILENAME, INFILE/INPUT, FILE/PUT

## Non-negotiable: no WARNINGs

Generated SAS code must run cleanly — **zero WARNINGs (and zero ERRORs) in the log**. Treat every `WARNING:` as a defect: uninitialized variables, implicit type conversions, truncation notes that should be warnings, "no observations", unresolved macro references, etc. If a warning is truly unavoidable, suppress it deliberately (e.g. an explicit option) and comment why. Likewise avoid superfluous NOTEs where reasonable.

## Style rules

These follow the @sasjs/core coding standards — apply them to all SAS code:

- One statement per line; indentation = 2 spaces, no tabs, no trailing whitespace
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
  - ALL macro variables must be `%local` unless deliberately global (globals should use an application prefix to avoid collisions); use `call symputx` (not `symput`) in DATA steps
  - Comment with `/* */` inside macros (asterisk comments are compiled into the macro)
  - Guard macro logic with `%length(&var)=0` checks rather than `&var=` (empty comparisons are unsafe)
- Avoid naming collisions: use `%sysfunc`-/`&syslast`-based work tables (e.g. `data &output; set &syslast; run;`) rather than hard-coded names

## Portability awareness

- Note when code differs between SAS 9.4 and Viya (e.g. CAS actions vs procs, `proc casutil` for sashdat loading, no X command on locked-down servers)
- Avoid hard-coded physical paths and engine-specific options unless asked

## Common pitfalls to flag when reviewing

- Unintended many-to-many MERGEs
- Automatic variable `_ERROR_` / implicit RETAIN surprises
- Macro timing issues: referencing `&macrovar` before it exists, `%if` evaluating data-step variables (use `if`/`symget` instead)
- Automatic macro variables (`&syscc`, `&syswarningtext`, `&syserrortext`, `&sysdate`, `&sysuserid`, etc.) are READ-ONLY — attempting to overwrite them (e.g. `%let syswarningtext=;` or `call symput('syscc',...)`) raises `ERROR: Unable to assign value to a macro variable that is read only` (or similar). Never try to "clear" them.
- Truncation from implicit length=8 on first assignment
- `proc sql` cartesian product warnings
