#!/usr/bin/env bash
set -euo pipefail

# No-op unless explicitly requested — non-SSL cases are unaffected.
[[ "${LOADSMITH_ENABLE_SSL:-}" == "on" ]] || exit 0

# Generate a self-signed server certificate inside $PGDATA.
# Clients connecting with tls.mode: require encrypt the channel without
# verifying this cert, so the CN and issuer don't matter.
openssl req -new -x509 -nodes -days 3650 \
    -subj "/CN=loadsmith-lab-postgres-ssl" \
    -keyout "${PGDATA}/server.key" \
    -out    "${PGDATA}/server.crt"
chmod 600 "${PGDATA}/server.key"

# Enable SSL in postgresql.conf.
# Postgres honours the last occurrence of a parameter, so appending is safe.
cat >> "${PGDATA}/postgresql.conf" <<'EOF'

# SSL enabled by LOADSMITH_ENABLE_SSL=on
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file  = 'server.key'
EOF
