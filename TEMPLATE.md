# Open Connector (Connect Anything): composer spec

Listing name: **Open Connector (Connect Anything)**
Description (72 chars): Auth gateway linking 1,700+ SaaS apps to AI agents via MCP, API and SDK.
Category: AI/ML. Icon: `https://cdn.jsdelivr.net/gh/oomol-lab/open-connector@v1.10.0/web/public/favicon.png` (64×64 PNG from the upstream repo).
Repository: `baranberkay96/open-connector-railway` (this folder is the repo root).

## Services

| Service | Source | Public | Volume | Healthcheck |
|---|---|---|---|---|
| Open Connector | repo `/services/connector` (`FROM ghcr.io/oomol-lab/open-connector:v1.10.0@sha256:508a…b83a` + `railway-start.sh`) | domain → 3000 | `/app/data` | `/health`, 900 s |
| Postgres | image `ghcr.io/railwayapp-templates/postgres-ssl:18.6@sha256:4fc8…c863` | no | `/var/lib/postgresql/data` | — |

Image: 118 MB compressed (amd64), far below the 4 GB Trial/Free image cap. The build only adds one file, no downloads.

## Boot sequence (Open Connector)

`railway-start.sh` (STANDARD 8.29: no deploy-form value fails the deploy):

1. `PORT` non-numeric or out of range → 3000. `HOST=::` (dual-stack).
2. `OOMOL_CONNECT_DATA_DIR` not creatable → `/app/data`.
3. `OOMOL_CONNECT_ORIGIN` empty/invalid → `https://$RAILWAY_PUBLIC_DOMAIN`; a path is stripped (a path is a mount prefix and would break `/health`).
4. Admin token or runtime token under 16 characters → random token (fail closed: console or `/v1` + `/mcp` locked, never open), warning in the log.
5. `OOMOL_CONNECT_OAUTH_AUTH_MODE=none` or invalid → `runtime_token`; invalid `OOMOL_CONNECT_MCP_OUTPUT_MODE` → unset. Both would otherwise either open the API or make the server throw at start.
6. Empty encryption key → generated key persisted at `/app/data/.railway-encryption-key` (instead of plaintext storage).
7. `postgres://` / `postgresql://` URL → `node scripts/runtime-data.ts migrate`, retried every 10 s up to 60 times (Postgres may start later), then exit 1 so Railway restarts. Empty URL → SQLite on the volume. Other values → SQLite with a warning.
8. `exec /usr/local/bin/open-connector` (upstream entrypoint → `serve`).

Migrations run in the start script, not in `preDeployCommand`: the pre-deploy runs without the entrypoint and fails the deploy at once if Postgres is still starting, while the start script can wait inside the 900 s healthcheck window.

## Improvements over market templates

No usable market base: the only marketplace entry (`open-connector`, 1 project on 2026-11-19) was not used. Compared with upstream's own `docker-compose.yml`:

- Image pinned by release tag and digest instead of `latest`.
- PostgreSQL instead of SQLite for the runtime database, with migrations on every boot.
- Runtime auth is on from the start: upstream leaves `/v1` and `/mcp` open until a token exists, which on a public domain exposes every connected account.
- Encryption key, admin token and runtime token generated per deploy.

## Resource estimate

| Service | Idle RAM | Typical RAM | CPU |
|---|---|---|---|
| Open Connector | ~0.15 GB | 0.2-0.4 GB | low; spikes with agent calls |
| Postgres | ~0.06 GB | 0.1 GB | low |

About $3-6/month at Railway prices (RAM $10/GB-month, vCPU $20/month, volumes $0.15/GB-month). Every plan works, Free included (0.5 GB per service). Measure on the first deploy test and correct this table.

## Verification checklist

- `/health` → `{"ok":true}` on the public domain.
- `/api/...` without the admin token → 401/403; with it → 200.
- `/v1/...` and `/mcp` without a runtime token → 401; with `OOMOL_CONNECT_RUNTIME_TOKEN` → accepted.
- Deploy log: `PostgreSQL schema is up to date`, then `connect server listening`; no "runtime API authentication is disabled" warning.
- Redeploy: data in Postgres and `/app/data` survive.

## Open questions

- OAuth provider apps: OOMOL's managed OAuth clients may not cover self-hosted origins for every provider; some providers need the user's own OAuth app (`OOMOL_CONNECT_ALLOWED_CUSTOM_OAUTH`). Not tested per provider.
- MCP OAuth (`OOMOL_CONNECT_OAUTH_ENABLED`, `OOMOL_CONNECT_OAUTH_AUTH_MODE=mixed`) for clients like claude.ai custom connectors is off by default; not exposed in the deploy form.
