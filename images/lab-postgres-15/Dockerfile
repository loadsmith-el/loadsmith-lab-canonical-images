# DATA_REF is this image's pinned canonical-data revision — an independent,
# per-image choice (decoupled from the postgres base version). It must match a
# loadsmith-lab-canonical-data git tag / VERSION; the CI derives the published
# `:data-<ref>` tag from it. Declared globally so both stages see it; override
# either with --build-arg (e.g. DATA_REPO=file://… for local/offline builds).
ARG DATA_REPO=https://github.com/loadsmith-el/loadsmith-lab-canonical-data.git
ARG DATA_REF=v1

# ── stage 1: generate the canonical CSV from the data repo (pinned) ──
# The dataset is deterministic (seed=42, stdlib-only), so it's regenerated at
# build time rather than committed anywhere.
FROM python:3-slim AS data
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ARG DATA_REPO
ARG DATA_REF
RUN git clone --depth 1 --branch "${DATA_REF}" "${DATA_REPO}" /gen \
 && python /gen/generate.py
# → /gen/spacecraft_telemetry_events.csv

# ── stage 2: the seeded postgres image ──
FROM postgres:15

# Stamp the baked-in dataset revision so a pulled image self-reports it
# (`docker inspect`). Mirrors the CI's derived `:data-<ref>` tag.
ARG DATA_REF
LABEL org.opencontainers.image.version="${DATA_REF}"

# openssl: needed by 02_ssl.sh to generate a self-signed cert when
# LOADSMITH_ENABLE_SSL=on is set. Installed in the base image so the script
# has no network dependency at runtime.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends openssl \
 && rm -rf /var/lib/apt/lists/*

# The canonical CSV comes from the data stage above — nothing committed to this
# repo, no host build context needed for it.
COPY --from=data /gen/spacecraft_telemetry_events.csv /docker-entrypoint-initdb.d/events.csv
COPY init.sql   /docker-entrypoint-initdb.d/01_init.sql

# Conditionally enables SSL when LOADSMITH_ENABLE_SSL=on. No-op otherwise.
COPY 02_ssl.sh  /docker-entrypoint-initdb.d/02_ssl.sh
RUN chmod 755   /docker-entrypoint-initdb.d/02_ssl.sh

ENV POSTGRES_DB=lab
ENV POSTGRES_USER=lab
ENV POSTGRES_PASSWORD=lab
