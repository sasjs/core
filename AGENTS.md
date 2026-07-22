# Agent Instructions for @sasjs/core

Follow these rules when editing or generating code for the @sasjs/core SAS macro library.

## Project Context
This repo is the SASjs Macro Core library — a collection of MIT-licensed, production-quality SAS macros for SAS application development.

## Versioning
- NEVER bump or modify the version in `package.json`.
- Versioning is handled entirely by the CI/CD pipeline using semantic-release.

## SAS Style & Standards
- Read and follow the standards documented in `README.md` (Sections: Components, Standards, File Properties, Header Properties, Coding Standards).
- Read and follow `.sasjslint`:
  - No trailing spaces.
  - Requires a Doxygen header on every macro (`@file`, `@brief`, etc.).
  - Lowercase file names without spaces.
  - Lowercase macro names.
  - Macro definitions must use parentheses, e.g. `%macro x();` not `%macro x;`.
  - Indentation = 2 spaces (or multiple thereof); no tabs.
  - Max line length 300.
  - No gremlins / invisible characters.
- One macro per file; filename must match macro name.
- Macro *calls* should NOT be terminated with a semicolon. Use `%my_macro()` not `%my_macro();`.
- Macro variables must always be local, to prevent scope leakage.


## Testing
- Read `.agents/docs/tests.md` for details on how the testing process works (how to run tests, structure, assertions, and where to find logs/results).

## Markdown Files
- Markdown files must not use word-wrap: never insert carriage returns mid-sentence. Each sentence/paragraph stays on one line.

## Build / Generated Files
- Do not run the build script locally; it is executed in the CI/CD pipeline.
- Generated files, including the consolidated `all.sas`, the per-folder `mc_*.sas` files, and the LUA macro wrappers in the `lua` folder, can generally be ignored unless the pipeline requires an update. Do not edit generated files by hand.
- run sasjs lint after each change