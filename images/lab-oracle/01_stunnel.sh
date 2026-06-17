#!/usr/bin/env bash
# gvenzl start-up hook (/container-entrypoint-startdb.d): runs on every container
# start, after the database is open. The lab uses ephemeral containers (no
# persisted volume), so this runs on every case run.
#
# Launches the stunnel TLS terminator that fronts Oracle's plaintext listener on
# 2484 → 127.0.0.1:1521, giving the connector a TCPS endpoint. No-op unless
# LOADSMITH_ENABLE_TLS=on, so non-TLS cases pay nothing. See README.md § TLS.
set -euo pipefail

[[ "${LOADSMITH_ENABLE_TLS:-}" == "on" ]] || exit 0

echo "lab-oracle: starting stunnel TLS terminator on :2484 → 127.0.0.1:1521"
stunnel /etc/stunnel/stunnel.conf
