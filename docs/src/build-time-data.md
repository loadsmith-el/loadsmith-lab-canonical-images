# Build-time Seed Data

No CSV is committed in this repo. Each image's Dockerfile has a `data` build
stage that clones
[`loadsmith-lab-canonical-data`](https://loadsmith-el.github.io/loadsmith-lab-canonical-data/)
at a pinned `DATA_REF` and runs its `generate.py` (deterministic, stdlib-only),
then `COPY --from=data ...` bakes the result into the final image:

```dockerfile
FROM python:3-slim AS data
RUN apt-get update -qq && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ARG DATA_REPO=https://github.com/loadsmith-el/loadsmith-lab-canonical-data.git
ARG DATA_REF=v1
RUN git clone --depth 1 --branch "${DATA_REF}" "${DATA_REPO}" /gen && python /gen/generate.py

FROM postgres:15
COPY --from=data /gen/spacecraft_telemetry_events.csv /docker-entrypoint-initdb.d/events.csv
COPY init.sql /docker-entrypoint-initdb.d/01_init.sql
ENV POSTGRES_DB=lab POSTGRES_USER=lab POSTGRES_PASSWORD=lab
```

**Tradeoff:** a cold build needs network access (the clone); cached images and
every case run are fully offline.

## The rules

- **Never commit a CSV** (or any large generated data file). Mirror
  `images/lab-postgres-15/Dockerfile`'s `data` stage exactly.
- **Pin `DATA_REF` to a tag** for reproducible builds. `DATA_REPO` / `DATA_REF`
  are `ARG`s with sane defaults, overridable via `--build-arg` for local/offline
  builds.
- **Credentials are always `lab` / `lab` / `lab`** (user / password / database
  or index), set via the image's native env vars, so every case is uniform.
- **Empty string means NULL** in the canonical CSV — the init/load step must
  treat empty fields as NULL (e.g. Postgres `COPY ... WITH (NULL '')`).
- **The lab tars only this directory's files** as the build context — don't rely
  on anything outside `images/<name>/` being present at build time except what
  the `data` stage fetches itself.
- **No DuckDB, no Parquet, no apt-get for data tooling** — the canonical CSV is
  the universal input format; prefer the target service's native CSV bulk loader
  (`COPY`, `LOAD DATA INFILE`, `clickhouse-client --query`, …).

`DATA_REF` is each image's **independent** choice of canonical-data revision
(decoupled from the service base version). It must match a tag/`VERSION` in
[`loadsmith-lab-canonical-data`](https://loadsmith-el.github.io/loadsmith-lab-canonical-data/);
the image CI derives its published `:data-<ref>` tag from it — see
[CI & Registry](./ci-and-registry.md).
