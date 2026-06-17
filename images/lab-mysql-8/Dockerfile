# DATA_REF is this image's pinned canonical-data revision — an independent,
# per-image choice (decoupled from the mysql base version). It must match a
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

# ── stage 2: the seeded mysql image ──
# `mysql:8` (major-rolling, currently 8.4) — mirrors the `postgres:15`
# convention. The connector exercises BOTH auth plugins, so the image provides
# both: the default `lab` user keeps the server-default caching_sha2_password
# (the only option in MySQL 9), and init.sql adds a `lab_native` user on the
# legacy mysql_native_password (MySQL 5.x). 8.4 disables that legacy plugin by
# default, so native-auth.cnf re-enables it (see that file).
FROM mysql:8

# Stamp the baked-in dataset revision so a pulled image self-reports it
# (`docker inspect`). Mirrors the CI's derived `:data-<ref>` tag.
ARG DATA_REF
LABEL org.opencontainers.image.version="${DATA_REF}"

# The canonical CSV lives in MySQL's secure_file_priv directory
# (default `/var/lib/mysql-files/`) so the init script's server-side
# `LOAD DATA INFILE` is permitted to read it. World-readable so mysqld can open
# it. Nothing is committed to this repo — the CSV comes from the data stage.
COPY --from=data /gen/spacecraft_telemetry_events.csv /var/lib/mysql-files/events.csv
COPY init.sql /docker-entrypoint-initdb.d/01_init.sql

# Re-enable the legacy mysql_native_password plugin (disabled by default on 8.4)
# so init.sql's `lab_native` user — and thus the connector's native_password
# path — works on the rolling base. No-op on versions where it's already on.
COPY native-auth.cnf /etc/mysql/conf.d/native-auth.cnf

# MySQL 8 ships with TLS enabled and auto-generated server certificates, so the
# `tls.mode: require` case needs no extra setup. Uniform lab credentials.
ENV MYSQL_DATABASE=lab
ENV MYSQL_USER=lab
ENV MYSQL_PASSWORD=lab
ENV MYSQL_ROOT_PASSWORD=lab
