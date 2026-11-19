# Deploy and Host OpenConnector with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/open-connector-connect-anything?referralCode=20H68q)

OpenConnector is an open-source auth gateway that connects AI agents to 1,700+ SaaS providers through MCP, HTTP, an SDK, a CLI and OpenAPI. This community template runs OpenConnector v1.10.0 with PostgreSQL, a persistent volume, encrypted credential storage and token-protected console and agent endpoints.

## About Hosting OpenConnector

OpenConnector keeps the OAuth tokens and API keys of the accounts you connect (GitHub, Gmail, Slack, Notion, HubSpot and many more) and lets agents call provider actions without ever seeing those secrets. Hosting it means one Node.js service on a public HTTPS domain, so OAuth providers can redirect back to it, plus a database for connections, tokens and run history. This template pins the official image by digest, runs the PostgreSQL migrations on boot and retries them while the database starts, encrypts stored credentials with a generated key, and protects both the admin console and the `/v1` and `/mcp` endpoints with generated tokens from the first second.

## Common Use Cases

- Give Claude, ChatGPT, Cursor or your own agents one MCP endpoint for many SaaS tools
- Keep OAuth tokens and API keys out of prompts, agent code and laptops
- Call provider actions over plain HTTP or the SDK from scripts, workflows and backends
- Issue separate runtime tokens per agent, each limited to chosen actions, proxies and connections
- Self-host the integration layer of an AI product instead of using a hosted connector service

## Dependencies for OpenConnector Hosting

- OpenConnector v1.10.0 (`ghcr.io/oomol-lab/open-connector`, official image, pinned by digest)
- PostgreSQL 18 (Railway's `postgres-ssl` image)

### Deployment Dependencies

- Source and releases: https://github.com/oomol-lab/open-connector
- Docker image guide: https://github.com/oomol-lab/open-connector/blob/main/docs/docker-ghcr.md
- Configuration reference: https://github.com/oomol-lab/open-connector/blob/main/docs/configuration.md
- Connecting providers: https://github.com/oomol-lab/open-connector/blob/main/docs/credentials.md

### Implementation Details

| Service | Role | Public |
|---|---|---|
| Open Connector | Web console, admin API, `/v1` actions API, `/mcp` endpoint, OAuth callbacks; volume at `/app/data` | **yes** |
| Postgres | Connections, runtime tokens, OAuth settings and run history; private only, with a volume | no |

**First login**

1. Wait until the Open Connector service is healthy (`/health` returns `{"ok":true}`). The first deploy builds a thin layer on the official image and runs the database migrations, which takes a minute or two.
2. Open the Open Connector service → Variables and copy `OOMOL_CONNECT_ADMIN_TOKEN`.
3. Open the service's public domain and paste the token into the console's unlock screen.
4. Connect a provider: pick a service, then sign in with OAuth or enter its API key. OAuth redirect URLs use `https://{your-domain}`.

**Connecting agents.** Agents call `https://{your-domain}/mcp` (MCP) or `https://{your-domain}/v1/...` (HTTP) with `Authorization: Bearer {runtime-token}`. `OOMOL_CONNECT_RUNTIME_TOKEN` is a ready bootstrap token. For each agent, better create its own token in the console's Access tab and limit it to the actions and connections it needs; only token hashes are stored.

**Keep `OOMOL_CONNECT_ENCRYPTION_KEY`.** It encrypts every stored credential. Save a copy in your password manager. If it changes, stored credentials can no longer be read and the accounts have to be connected again.

**Safe defaults.** Values typed into the deploy form never break the deploy. A missing or too short admin or runtime token (under 16 characters) is replaced by a random one nobody knows, so the console or agent API stays locked instead of open; the deploy log says how to fix it. An empty encryption key gets a generated key stored on the volume instead of plaintext storage. An invalid origin falls back to the Railway domain.

**Custom domain.** Add it in the service's Settings → Networking, then set `OOMOL_CONNECT_ORIGIN=https://{your-domain}` and redeploy, so OAuth redirects use it. Update the redirect URL in any custom OAuth apps you registered.

**SQLite instead of PostgreSQL.** Clear `OOMOL_CONNECT_DATABASE_URL` and delete the Postgres service: OpenConnector then keeps everything in SQLite on its own volume. The two backends are not synced, so pick one before you connect accounts.

**Resources and plans.** OpenConnector's own deployment guides size it at 512 MB of RAM; idle use is well below that, and Postgres needs about 0.1 GB. That fits every Railway plan, including Trial and Free, at roughly $3-6 a month in usage for a small team. Heavy agent traffic mainly adds CPU.

**Scaling.** One instance serves many agents. For several replicas OpenConnector needs shared transit-file storage (S3-compatible) and no volume; see the configuration reference before scaling out.

**Upgrading.** The version is pinned in `services/connector/Dockerfile` (tag and digest). Migrations run automatically on every boot before the server starts. To choose a version yourself, eject the service to your own repo and change the `FROM` image to another release tag.

**License.** OpenConnector uses a modified Apache 2.0 license: running it for your own organization, for a client's own organization, or inside your own product is allowed; offering it to third parties as a hosted connector service needs a commercial license from OOMOL. This is a community template, not affiliated with OOMOL.

### Why Deploy OpenConnector on Railway?

Railway gives OpenConnector what it needs to work with OAuth providers: a stable HTTPS domain, a private PostgreSQL database and persistent storage, with no servers to manage. Deploy, paste your admin token, connect your accounts, and point your agents at one MCP endpoint.
