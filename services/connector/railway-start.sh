#!/bin/sh
# OpenConnector start on Railway.
# - A value typed into the deploy form never fails the deploy: it falls back to a safe default
#   with a warning, or locks access with a random token nobody knows (fail closed).
# - An empty OOMOL_CONNECT_ENCRYPTION_KEY gets a generated key that is kept on the volume.
# - With a PostgreSQL URL, migrations run first and are retried while the database starts.
# - Then the image's own entrypoint (/usr/local/bin/open-connector) starts the server.
set -eu

log() { echo "railway-start: $*"; }
warn() { echo "railway-start: WARNING: $*" >&2; }
random_hex() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
squeeze() { printf '%s' "$1" | tr -d ' \t\r\n'; }

cd /app

# Port Railway routes to and health-checks.
case "${PORT:-}" in
'' | *[!0-9]*) warn "PORT='${PORT:-}' is not a number; using 3000"; PORT=3000 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
	warn "PORT=$PORT is out of range; using 3000"
	PORT=3000
fi
# Dual-stack listener: the healthcheck uses IPv4, other services in the project may use IPv6.
HOST="::"
export PORT HOST

# Runtime data (SQLite database when no PostgreSQL URL is set, transit files, upload staging).
data_dir=${OOMOL_CONNECT_DATA_DIR:-/app/data}
if ! mkdir -p "$data_dir" 2>/dev/null; then
	warn "OOMOL_CONNECT_DATA_DIR='$data_dir' cannot be created; using /app/data (the volume)"
	data_dir=/app/data
	mkdir -p "$data_dir"
fi
OOMOL_CONNECT_DATA_DIR=$data_dir
export OOMOL_CONNECT_DATA_DIR

# Public origin: OAuth redirect URLs are built from it. A path would become a mount prefix that
# the healthcheck (/health) does not carry, so only scheme://host[:port] is accepted.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
	default_origin="https://$RAILWAY_PUBLIC_DOMAIN"
else
	default_origin="http://localhost:$PORT"
fi
origin=$(squeeze "${OOMOL_CONNECT_ORIGIN:-}")
origin=${origin%/}
case "$origin" in
http://?* | https://?*)
	host_part=${origin#*://}
	case "$host_part" in
	*/*)
		warn "OOMOL_CONNECT_ORIGIN='$origin' has a path; using ${origin%%://*}://${host_part%%/*}"
		origin="${origin%%://*}://${host_part%%/*}"
		;;
	esac
	;;
'') origin=$default_origin ;;
*)
	warn "OOMOL_CONNECT_ORIGIN='$origin' is not an http(s) URL; using $default_origin"
	origin=$default_origin
	;;
esac
OOMOL_CONNECT_ORIGIN=$origin
export OOMOL_CONNECT_ORIGIN

# Admin token: protects the web console, /api and /docs. Never left open on a public domain.
admin=$(squeeze "${OOMOL_CONNECT_ADMIN_TOKEN:-}")
if [ "${#admin}" -lt 16 ]; then
	warn "OOMOL_CONNECT_ADMIN_TOKEN is empty or shorter than 16 characters. The console and admin API are locked with a random token until you set a token of 16+ characters in the service Variables and redeploy."
	admin=$(random_hex)
fi
OOMOL_CONNECT_ADMIN_TOKEN=$admin
export OOMOL_CONNECT_ADMIN_TOKEN

# Bootstrap runtime token for /v1 and /mcp. Without any runtime auth these endpoints would be
# open to anyone, so an unusable value becomes a random token; tokens created in the console's
# Access tab keep working.
runtime=$(squeeze "${OOMOL_CONNECT_RUNTIME_TOKEN:-}")
if [ "${#runtime}" -lt 16 ]; then
	warn "OOMOL_CONNECT_RUNTIME_TOKEN is empty or shorter than 16 characters; using a random one. Create runtime tokens in the console's Access tab, or set a token of 16+ characters and redeploy."
	runtime=$(random_hex)
fi
OOMOL_CONNECT_RUNTIME_TOKEN=$runtime
export OOMOL_CONNECT_RUNTIME_TOKEN

case "${OOMOL_CONNECT_OAUTH_AUTH_MODE:-}" in
'' | runtime_token | oauth | mixed) ;;
none)
	warn "OOMOL_CONNECT_OAUTH_AUTH_MODE=none would open /v1 and /mcp to anyone on the public domain; using runtime_token"
	OOMOL_CONNECT_OAUTH_AUTH_MODE=runtime_token
	export OOMOL_CONNECT_OAUTH_AUTH_MODE
	;;
*)
	warn "OOMOL_CONNECT_OAUTH_AUTH_MODE='$OOMOL_CONNECT_OAUTH_AUTH_MODE' is not runtime_token, oauth or mixed; using runtime_token"
	OOMOL_CONNECT_OAUTH_AUTH_MODE=runtime_token
	export OOMOL_CONNECT_OAUTH_AUTH_MODE
	;;
esac

case "${OOMOL_CONNECT_MCP_OUTPUT_MODE:-}" in
'' | compatible | compact) ;;
*)
	warn "OOMOL_CONNECT_MCP_OUTPUT_MODE='$OOMOL_CONNECT_MCP_OUTPUT_MODE' is not compatible or compact; using compatible"
	unset OOMOL_CONNECT_MCP_OUTPUT_MODE
	;;
esac

# Encryption key for stored credentials. Losing it makes the stored credentials unreadable, so an
# empty variable never means "store in plaintext" here: a generated key is kept on the volume.
key_file="$data_dir/.railway-encryption-key"
if [ -z "$(squeeze "${OOMOL_CONNECT_ENCRYPTION_KEY:-}")" ]; then
	if [ -s "$key_file" ]; then
		log "OOMOL_CONNECT_ENCRYPTION_KEY is empty; using the key stored at $key_file"
	else
		(umask 077 && random_hex >"$key_file")
		warn "OOMOL_CONNECT_ENCRYPTION_KEY is empty; generated a key and stored it at $key_file. Copy it into the variable so it survives the loss of the volume."
	fi
	OOMOL_CONNECT_ENCRYPTION_KEY=$(cat "$key_file")
	export OOMOL_CONNECT_ENCRYPTION_KEY
fi

# Database: PostgreSQL when a postgres URL is set, otherwise SQLite on the volume.
db_url=$(squeeze "${OOMOL_CONNECT_DATABASE_URL:-}")
case "$db_url" in
postgres://?* | postgresql://?*)
	OOMOL_CONNECT_DATABASE_URL=$db_url
	export OOMOL_CONNECT_DATABASE_URL
	max_attempts=60
	attempt=1
	until node scripts/runtime-data.ts migrate; do
		if [ "$attempt" -ge "$max_attempts" ]; then
			warn "PostgreSQL migrations still fail after $max_attempts attempts; exiting so Railway restarts the service. Check that the Postgres service is running and OOMOL_CONNECT_DATABASE_URL is right."
			exit 1
		fi
		log "PostgreSQL not ready or migration failed (attempt $attempt/$max_attempts); retrying in 10 s"
		attempt=$((attempt + 1))
		sleep 10
	done
	log "PostgreSQL schema is up to date"
	;;
'')
	unset OOMOL_CONNECT_DATABASE_URL
	log "no OOMOL_CONNECT_DATABASE_URL; using SQLite at $data_dir/connect.sqlite"
	;;
*)
	warn "OOMOL_CONNECT_DATABASE_URL is not a postgres:// or postgresql:// URL; using SQLite at $data_dir/connect.sqlite instead"
	unset OOMOL_CONNECT_DATABASE_URL
	;;
esac

log "origin $OOMOL_CONNECT_ORIGIN, port $PORT, data $data_dir"
exec /usr/local/bin/open-connector "$@"
