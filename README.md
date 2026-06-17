# loadsmith-lab-canonical-images

> 📖 **Full documentation:** <https://loadsmith-el.github.io/loadsmith-lab-canonical-images/>

The **`images` origin** for [loadsmith-lab](../loadsmith-lab): Docker build
contexts for the service images its cases run against.

## Layout

```text
loadsmith-lab.toml      manifest: name → description
images/<name>/
  Dockerfile             multi-stage: generates the seed CSV at build time, then bakes it in
  init.sql / init.*      schema + bulk load for the canonical dataset
```

The directory name *is* the item name (no prefix stripping) and is built under
the local tag `loadsmith-lab/images/<name>:local`. Add an entry under `[images]`
in `loadsmith-lab.toml` whenever you add an image.

## Images

| Image | Description |
|---|---|
| `lab-postgres-15` | Postgres 15 with the canonical `spacecraft_telemetry_events` seed data baked in |
| `lab-mysql-8` | MySQL 8 with the canonical `spacecraft_telemetry_events` seed data baked in (users `lab` / `caching_sha2_password` + `lab_native` / `mysql_native_password` cover both connector auth paths) |

## How an image gets its seed data

No CSV is committed in this repo. Each image's Dockerfile has a `data` build
stage that clones [`loadsmith-lab-canonical-data`](../loadsmith-lab-canonical-data)
at a pinned `DATA_REF` and runs its `generate.py` (deterministic, stdlib-only),
then `COPY --from=data ... events.csv` bakes the result into the final image:

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

Tradeoff: a cold build needs network access (the clone); cached images and every
case run are fully offline.

## CI & Registry

On push to `main`, GitHub Actions builds and publishes every `images/<name>/`
directory that changed (multi-arch, `linux/amd64` + `linux/arm64`) to GHCR:

```text
ghcr.io/loadsmith-el/<name>:latest
ghcr.io/loadsmith-el/<name>:sha-<shortsha>
ghcr.io/loadsmith-el/<name>:<version>
```

The `<version>` tag is resolved per image, in precedence order:

1. **An explicit `images/<name>/VERSION` file** (override), for images that
   version on their own axis — e.g. a future loadsmith engine image shipping
   `v0.3.0`.
2. **Else derived from the Dockerfile's `ARG DATA_REF`** — service images
   publish `:data-<ref>` reflecting the baked-in canonical dataset revision
   (e.g. `lab-postgres-15` → `:data-v1`). The dataset revision lives in
   `loadsmith-lab-canonical-data` (its `VERSION` file + git tag); `DATA_REF` is
   the single place this image pins it, so there's nothing to hand-maintain
   here. The image also carries it as an OCI label
   (`org.opencontainers.image.version`), so a pulled image self-reports its
   data revision.

Only the images whose directory changed are rebuilt — unrelated images aren't
republished. To force a rebuild of everything (e.g. after bumping the
`DATA_REF` tag in `loadsmith-lab-canonical-data`), run the "Build & publish
images" workflow manually with `force_all: true`.

Pull requests touching `images/**` run the same build (without pushing) to
validate the Dockerfile.

`loadsmith-lab` doesn't yet pull these published images — `resolve_image`
still builds locally on demand. Registry consumption is a future step.

## Using this repo

Consumed by `loadsmith-lab` as an origin — register it once (local dev: read
live, no install):

```bash
loadsmith-lab origin local add images ../loadsmith-lab-canonical-images
loadsmith-lab build --select images/lab-postgres-15
```

A case in [`loadsmith-lab-canonical-catalog`](../loadsmith-lab-canonical-catalog) references an
image as `image: images/<name>`; it's auto-built on first run.

## Adding a new image

See [Adding Service Images](../loadsmith-lab/docs/src/writing-cases/adding-service-images.md)
and the `/create-source-image` Claude Code command in `../loadsmith-lab/.claude/commands/`.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
