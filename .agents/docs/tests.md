# Testing in @sasjs/core

## Overview

Tests are executed on a real SAS server using the SASjs CLI (`sasjs test`), not locally. Each test is a self-contained `.sas` file that is submitted to the server, and results are collected in the `sasjsresults` folder.

## Running Tests

```bash
npm test        # runs: npx @sasjs/cli test -t server
```

The `-t server` flag selects the target (server type) from `sasjs/sasjsconfig.json`.

## Test Structure

Test files live under `tests/` in subfolders by platform applicability:

- `tests/base` — run on all platforms (SAS 9 and Viya)
- `tests/sas9only` — SAS 9 only (metadata server macros)
- `tests/viyaonly` — Viya only
- `tests/serveronly` — SASjs Server only
- `tests/x-platform` — cross-platform (both SAS 9 and Viya)
- `tests/ddlonly` — DDL-related tests

Naming convention: `<macroname>.test.sas`, with numbered variants (`<macroname>.test.1.sas`, `.test.2.sas`, ...) for multiple tests of the same macro. File names are lowercase, matching the lint rules.

## Test Flow

1. **Init**: `tests/testinit.sas` runs before every test (configured in `sasjsconfig.json` under `testConfig.initProgram`). It sets up a unique app location (`mcTestAppLoc`), the compute context, calls `%mp_init()`, and enables debug options when `_debug` is set.
2. **Test body**: the test file itself runs. It should use `%mp_assert()` to record results into `work.test_results`:

```sas
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking for error condition,
  outds=work.test_results
)
```

3. **Term**: `tests/testterm.sas` runs after every test (`testConfig.termProgram`). It adds a final assertion that `&syscc=0`, then writes the results as JSON via `%webout(OPEN) / %webout(OBJ,TEST_RESULTS) / %webout(CLOSE)`.

## Results

After a test run, check the `sasjsresults` folder:

- `testResults.json` / `testResults.xml` / `testResults.csv` — per-test PASS/FAIL with descriptions and comments
- `logs/<testname>.log` — the full SAS log for each test; check here first when a test fails
- `coverage.lcov` — coverage data

## Writing Tests — Things to Know

- Tests follow the same Doxygen header and lint standards as regular macros (`@file`, `@brief`, `<h4> SAS Macros </h4>` listing macros used).
- Macro *calls* are not terminated with semicolons: use `%mp_assert(...)` not `%mp_assert(...);`.
- Use `%mp_assert(iftrue=(...), desc=..., outds=work.test_results)` for every check — always append to `work.test_results`.
- When comparing datasets after a round trip (eg through JSON), do not assert `proc compare` SYSINFO=0 directly — SYSINFO is a bitmask that includes attribute differences (length, format, label) which round trips legitimately change. Mask it to data-related bits only (64=missing obs in compare, 128=extra obs in compare, 4096=unequal values, 32768=obs count differs). Note `SYSINFO` is a read-only automatic macro variable, so store the masked value in a new variable.
- Be careful with character data round trips: `cats()` and the plain `$` informat strip leading blanks; use `trim()` and `$char` where leading blanks must be preserved.
- After any change, run `npx sasjs lint`.
- Do not edit generated copies under `sasjsbuild/` — they are refreshed by the CI build.
