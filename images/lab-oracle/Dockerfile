# DATA_REF is this image's pinned canonical-data revision — an independent,
# per-image choice (decoupled from the Oracle base version). It must match a
# loadsmith-lab-canonical-data git tag / VERSION; the CI derives the published
# `:data-<ref>` tag from it. Declared globally so both stages see it; override
# either with --build-arg (e.g. DATA_REPO=file://… for local/offline builds).
ARG DATA_REPO=https://github.com/loadsmith-el/loadsmith-lab-canonical-data.git
ARG DATA_REF=v1

# ── stage 1: generate the canonical CSV from the data repo (pinned) ──
# The dataset is deterministic (seed=42, stdlib-only), so it's regenerated at
# build time rather than committed anywhere. The csv writer emits CRLF; Oracle's
# external table is simplest with LF, so we strip CR here → events.csv.
FROM python:3-slim AS data
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ARG DATA_REPO
ARG DATA_REF
RUN git clone --depth 1 --branch "${DATA_REF}" "${DATA_REPO}" /gen \
 && python /gen/generate.py \
 && tr -d '\r' < /gen/spacecraft_telemetry_events.csv > /gen/events.csv
# → /gen/events.csv (LF)

# ── stage 2: the seeded Oracle image ──
# gvenzl/oracle-free:23-slim — the free Oracle DB (currently the 26ai engine),
# multi-arch (amd64 + arm64). The slim variant ships no orapki/JDK, which is why
# the lab's TLS endpoint is an stunnel terminator rather than native Oracle TCPS
# (see README.md § TLS).
FROM gvenzl/oracle-free:23-slim

# Stamp the baked-in dataset revision so a pulled image self-reports it
# (`docker inspect`). Mirrors the CI's derived `:data-<ref>` tag.
ARG DATA_REF
LABEL org.opencontainers.image.version="${DATA_REF}"

# stunnel provides the TLS terminator in front of the plaintext TNS listener.
# It's in the Oracle Linux base repos (no EPEL needed). Installed as root.
USER root
RUN microdnf install -y stunnel \
 && microdnf clean all

# The canonical CSV (LF) lives in a directory the external table reads from.
COPY --from=data --chown=oracle:oinstall /gen/events.csv /opt/oracle/seed/events.csv

# Seed script (runs once, as sysdba, on first init — every run in the lab since
# containers are ephemeral). Builds the schema + loads the CSV via external table.
COPY --chown=oracle:oinstall init.sql /container-entrypoint-initdb.d/01_init.sql

# TLS terminator: config + leaf cert (cert+key). The committed self-signed lab
# cert is intentional — see README.md § TLS and tls/README.md. stunnel is started
# by the start-up hook only when LOADSMITH_ENABLE_TLS=on (no-op otherwise).
COPY --chown=oracle:oinstall stunnel.conf /etc/stunnel/stunnel.conf
COPY --chown=oracle:oinstall tls/server.pem /etc/stunnel/server.pem
COPY --chown=oracle:oinstall 01_stunnel.sh /container-entrypoint-startdb.d/01_stunnel.sh
RUN chmod 0644 /etc/stunnel/server.pem \
 && chmod 0755 /container-entrypoint-startdb.d/01_stunnel.sh

# gvenzl creates SYS/SYSTEM with ORACLE_PASSWORD and an APP_USER (`lab`) in the
# default pluggable database FREEPDB1 before the init script runs. Uniform lab
# credentials, matching the postgres/mysql images.
ENV ORACLE_PASSWORD=lab
ENV APP_USER=lab
ENV APP_USER_PASSWORD=lab

# Restore the base image's runtime user (the entrypoint expects to run as oracle).
USER oracle
