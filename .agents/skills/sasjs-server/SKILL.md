---
name: sasjs-server
description: Installing, configuring, and running @sasjs/server — the open-source NodeJS wrapper around the SAS binary that provides a REST API, filesystem (SASjs Drive), Stored Program execution, and web app streaming. Covers desktop vs server modes, runtime configuration (SAS/JS/Python/R), environment variables, auth (tokens, LDAP), and mock server types. Use when deploying, troubleshooting, or developing against sasjs/server.
---

# @sasjs/server

SASjs Server is an open-source NodeJS wrapper for calling the SAS binary executable. It runs on a real SAS server or a local desktop and provides:

- A filesystem (SASjs Drive) for storing SAS programs and content
- Execution of Stored Programs from a URL (equivalent to SAS 9 Stored Processes / Viya Jobs)
- Web app streaming (serve frontend apps straight from SAS content)
- A REST API with Swagger docs
- Portability: apps built for SASjs Server deploy unchanged to SAS 9 / Viya via @sasjs/cli

## Modes

- **Desktop mode** (`MODE=desktop`, default): single-user, no authentication, no database. CORS enabled by default.
- **Server mode** (`MODE=server`): multi-user with authentication, requires a database (`DB_CONNECT`, `DB_TYPE=mongodb|cosmos_mongodb`). CORS disabled by default — configure `WHITELIST` if enabling.

## Installation

Download the relevant zip from GitHub releases and run the packaged executable (`api-linux`, etc.):

```bash
curl -L https://github.com/sasjs/server/releases/latest/download/linux.zip > linux.zip
unzip linux.zip && ./api-linux
```

On first run it prompts (unless set as env vars) for the SAS executable path and the filesystem location for Stored Programs/temp files. Docker is also supported (`DockerfileApi`, docker-compose files in the repo).

## Configuration via environment variables

Set in `/etc/environment`, exported, prepended to the command, or in a `.env` file alongside the executable. Key variables:

| Variable | Purpose |
|---|---|
| `MODE` | `desktop` (default) or `server` |
| `SAS_PATH` | Path to `sas.exe` / `sas.sh` |
| `RUN_TIMES` | Comma-separated runtime priority, e.g. `sas,js,py` — options: `sas`, `js`, `py`, `r`. Each needs its path: `SAS_PATH`, `NODE_PATH`, `PYTHON_PATH`, `R_PATH` |
| `SASJS_ROOT` | Working directory: SAS WORK, staged files, drive, config |
| `DRIVE_LOCATION` | Location for files, sasjs packages, `appStreamConfig.json` |
| `PROTOCOL` / `PORT` | `http` (default) or `https` (needs `PRIVATE_KEY`, `CERT_CHAIN`, optional `CA_ROOT`); default port 5000 |
| `SAS_OPTIONS` / `SASV9_OPTIONS` | Extra SAS system options auto-applied to sessions (Windows vs Unix), e.g. `-NOXCMD` |
| `DB_CONNECT` / `DB_TYPE` | MongoDB connection string / type — required for server mode |
| `AUTH_PROVIDERS` + `LDAP_*` | LDAP auth: `LDAP_URL`, `LDAP_BIND_DN`, `LDAP_BIND_PASSWORD`, `LDAP_USERS_BASE_DN`, `LDAP_GROUPS_BASE_DN` |
| `CORS` / `WHITELIST` | Enable CORS and whitelist space-separated origins |
| `MOCK_SERVERTYPE` / `STATIC_MOCK_LOCATION` | Emulate `sas9`/`sasviya` API responses for frontend testing against a sasjs server |

## Developing against the API

- Server type for @sasjs/adapter / CLI targets is `SASJS` (`serverType: 'SASJS'`); auth is token-based.
- The REST API is self-documented via Swagger on the running instance.
- Server-side execution uses `ms_*` macros from @sasjs/core (e.g. `ms_createfile`, `ms_adduser2group`) — services/jobs deployed by the CLI work as on other platforms.
- Repo layout (for contributors): `api/` (Express/TypeScript backend: controllers, routes, middlewares, model), `web/` (frontend), `restClient/` (REST examples), `mongo-seed/` (server-mode DB seed).
