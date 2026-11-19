# Notice

## Upstream software

This repository contains Railway configuration and a small start script only. OpenConnector is pulled at build time from its official image; it is not stored in this repository.

| Software | License | Source (publisher) |
|---|---|---|
| OpenConnector v1.10.0 | OpenConnector License (modified Apache 2.0), Copyright 2026 OOMOL | `ghcr.io/oomol-lab/open-connector:v1.10.0@sha256:508acc68b237ab75e5afab35a4df2f2a864ab66520b2913623568f6086bab83a` (OOMOL) |
| PostgreSQL 18 | PostgreSQL License | `ghcr.io/railwayapp-templates/postgres-ssl:18.6@sha256:4fc833b43d2aaf6ecc9b18615f5533602b723a32d0e2efe2dae8ca0f7217c863` (Railway; MIT-licensed image repository) |

OpenConnector's license: https://github.com/oomol-lab/open-connector/blob/v1.10.0/LICENSE.txt. It allows running OpenConnector for your own organization, for a client's own organization and inside your own products; providing it to third parties as a hosted connector service needs a commercial license from OOMOL. Each deployment of this template is a separate instance run by the person who deploys it.

`services/connector/railway-start.sh` is written for this template. It calls the image's own entrypoint and migration script and contains no upstream code.

## Verified against

| What | Upstream file | Ref | Checked |
|---|---|---|---|
| Latest release and image tag scheme (`v1.10.0`, `latest`, `tip`) | GitHub releases, `.github/workflows/publish-docker.yml`, ghcr.io manifest | `v1.10.0` | 2026-11-19 |
| Image layout (port 3000, `/app/data`, entrypoint `serve` / `migrate`, Node 24 alpine) | `docker/Dockerfile`, `docker/entrypoint.sh` | `v1.10.0` | 2026-11-19 |
| Environment variables, PostgreSQL migrations, runtime and admin auth | `docs/configuration.md`, `docs/docker-ghcr.md`, `src/server/index.ts`, `scripts/runtime-data.ts` | `v1.10.0` | 2026-11-19 |
| Encryption key handling (any non-empty passphrase, scrypt-derived AES-256-GCM key) | `src/server/secrets/secret-codec.ts` | `v1.10.0` | 2026-11-19 |
| Health endpoint `/health` and 512 MB sizing | `docs/docker-ghcr.md`, `fly.toml` | `v1.10.0` | 2026-11-19 |
| PostgreSQL client (node-postgres, no TLS unless the URL asks for it) | `src/server/storage/postgres/runtime-store.ts`, `package.json` | `v1.10.0` | 2026-11-19 |
| Railway Postgres image (`18.6` = `18`) | ghcr.io tags of `railwayapp-templates/postgres-ssl` | 18.6 | 2026-11-14 |
