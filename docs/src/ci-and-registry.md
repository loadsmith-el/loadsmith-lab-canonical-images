# CI & Registry

On push to `main`, GitHub Actions (`build-images.yml`) builds and publishes every
`images/<name>/` directory that **changed** (multi-arch, `linux/amd64` +
`linux/arm64`) to GHCR:

```text
ghcr.io/loadsmith-el/<name>:latest
ghcr.io/loadsmith-el/<name>:sha-<shortsha>
ghcr.io/loadsmith-el/<name>:<version>
```

## How the `<version>` tag is resolved

Per image, in precedence order:

1. **An explicit `images/<name>/VERSION` file** (override), for images that
   version on their own axis — e.g. a future loadsmith engine image shipping
   `v0.3.0`.
2. **Else derived from the Dockerfile's `ARG DATA_REF`** — service images publish
   `:data-<ref>` reflecting the baked-in canonical dataset revision (e.g.
   `lab-postgres-15` → `:data-v1`). The dataset revision lives in
   [`loadsmith-lab-canonical-data`](https://loadsmith-el.github.io/loadsmith-lab-canonical-data/)
   (its `VERSION` file + git tag); `DATA_REF` is the single place this image pins
   it, so there's nothing to hand-maintain here. The image also carries it as an
   OCI label (`org.opencontainers.image.version`), so a pulled image self-reports
   its data revision.

## Change detection

Only the images whose directory changed are rebuilt — unrelated images aren't
republished. To force a rebuild of everything (e.g. after bumping the `DATA_REF`
tag in `loadsmith-lab-canonical-data`), run the **"Build & publish images"**
workflow manually with `force_all: true`.

Pull requests touching `images/**` run the same build **without pushing**, to
validate the Dockerfile.

## Consumption note

`loadsmith-lab` doesn't yet pull these published images — `resolve_image` still
builds locally on demand. Registry consumption is a future step.
