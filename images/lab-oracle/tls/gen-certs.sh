#!/usr/bin/env bash
# Regenerates the lab's throwaway TLS material. Run from this directory.
#
# These certs are committed ON PURPOSE (see ../README.md § TLS). They are a
# self-signed CA + a leaf server cert for the in-image stunnel terminator. The
# Oracle (ODPI-C) client verifies the server against a wallet built from this CA,
# so the CA must be known at case-authoring time — hence committed, not generated
# at build. We need a real CA → leaf chain: the leaf carries CA:FALSE + serverAuth
# EKU + SANs for the service alias.
set -euo pipefail

# 1. self-signed CA (this is what clients pin via tls.root_cert)
openssl req -new -x509 -nodes -days 3650 \
  -subj "/CN=loadsmith-lab-oracle-ca" \
  -keyout ca.key -out ca.crt

# 2. leaf server cert signed by the CA
openssl req -new -nodes -subj "/CN=lab-oracle" \
  -keyout server.key -out server.csr
cat > ext.cnf <<'XEOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:oracle,DNS:localhost,IP:127.0.0.1
XEOF
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 3650 -extfile ext.cnf -out server.crt

# stunnel wants the cert + key concatenated in one PEM. The CA goes in too:
# Oracle's NZ TLS layer validates only against the chain the SERVER presents — it
# will NOT build the path from a CA it merely holds in its wallet (unlike
# openssl/rustls). So stunnel must serve the full leaf → CA chain, or the ODPI-C
# client fails with ORA-29024 (certificate validation failure).
cat server.crt ca.crt server.key > server.pem
chmod 644 server.pem ca.crt

# Cleanup intermediates we don't commit (the CA key is kept only to allow
# re-signing; safe to delete and regenerate the whole set when it expires).
rm -f server.csr ext.cnf ca.srl
echo "Generated: ca.crt (trust this), server.pem (stunnel leaf+CA chain + key), ca.key/server.key (signing material)"
