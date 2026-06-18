# A *mock* Microsoft Graph endpoint for the `sharepoint` connector's lab cases.
# There is no public SharePoint to seed, and Graph is just HTTP — so this image
# serves the slice of Graph the connector calls (OAuth token, file `/content`,
# List `items` with paging) backed by the canonical dataset. The connector's
# `graph_base_url`/`authority_url` point here, so the whole pipe runs end-to-end
# without a tenant. NOT a real Graph: only the routes the connector uses.
#
# It reuses the same canonical CSV as every other lab image (so file-mode reads
# the familiar 100k rows), and derives a small List fixture from it at runtime.

# DATA_REF pins the canonical-data revision (mirrors lab-postgres-15 / lab-mysql-8).
ARG DATA_REPO=https://github.com/loadsmith-el/loadsmith-lab-canonical-data.git
ARG DATA_REF=v1

# ── stage 1: generate the canonical CSV from the data repo (pinned) ──
FROM python:3-slim AS data
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ARG DATA_REPO
ARG DATA_REF
RUN git clone --depth 1 --branch "${DATA_REF}" "${DATA_REPO}" /gen \
 && python /gen/generate.py
# → /gen/spacecraft_telemetry_events.csv

# ── stage 2: the mock Graph HTTP server (stdlib-only Python) ──
FROM python:3-slim
ARG DATA_REF
LABEL org.opencontainers.image.version="${DATA_REF}"

COPY --from=data /gen/spacecraft_telemetry_events.csv /data/events.csv
COPY server.py /server.py

EXPOSE 8080
CMD ["python", "/server.py"]
