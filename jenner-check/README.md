# Jenner compatibility tests

[Jenner](https://jenneranalytics.com) is a complete SAS-compatible system
and collaborative workspace. Each `tNNN_*` directory in this folder is a
self-contained test bundle that submits a SAS program to the public API
at `https://api.jenneranalytics.com/v1/run` and checks the response.

## Bundle layout

```
tNNN_*/
├── script.sas      # the SAS program
├── autoexec.sas    # options + setup that prepend the script
├── input/          # sample data the script reads (if any)
├── expected.json   # stable assertions checked on each run
├── expected/       # captured snapshot from the last passing run
│   ├── log.txt     # the .log field, verbatim
│   ├── output.txt  # the .output (listing) field, verbatim
│   └── files.md    # links to ODS images, datasets, etc.
└── meta.json       # provenance: source file, blob sha, what was adapted
```

## Running a bundle

The runner concatenates `autoexec.sas` + `script.sas`, POSTs to
`https://api.jenneranalytics.com/v1/run`, and prints the result.

**Mac / Linux (bash + curl):**

```bash
./run_jenner.sh --all              # run every tNNN_* bundle, summary at end
./run_jenner.sh t001_something     # run one
./run_jenner.sh --list             # list bundles in this directory
```

**Windows:**

```cmd
run_jenner.bat tNNN_something
```

**From any SAS session (no curl needed):**

Submit `run_jenner.sas` — it uses PROC HTTP to POST and prints the
response.

**By hand with curl:**

```bash
cat tNNN_*/autoexec.sas tNNN_*/script.sas > /tmp/submit.sas
curl -sS -X POST https://api.jenneranalytics.com/v1/run \
  -F "script=@/tmp/submit.sas" \
  -F "deterministic=1" -F "timeout=60"
```

**Or in the hosted workspace:**

Open <https://jenneranalytics.com>, paste `script.sas` (with the
`autoexec.sas` lines prepended), upload anything in `input/`, and run.

## Artifact URLs

`expected/files.md` in each bundle lists hosted URLs for any ODS images,
datasets, or other artifacts produced by a captured run. Those URLs are
tied to a specific run and expire when the run is reaped — re-run the
bundle to refresh them.
