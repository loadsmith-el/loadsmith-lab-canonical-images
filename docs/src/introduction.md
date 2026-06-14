# Introduction

This repository is the **`images` origin** for
[loadsmith-lab](https://loadsmith-el.github.io/loadsmith-lab/): the Docker build
contexts for the service images its cases run against.

It is **content only** — no engine code. The runner that resolves and builds
these images lives in
[`loadsmith-lab`](https://loadsmith-el.github.io/loadsmith-lab/); a case in
[`loadsmith-lab-canonical-catalog`](https://loadsmith-el.github.io/loadsmith-lab-canonical-catalog/)
references an image here as `image: images/<name>`.

## The origin model

```text
loadsmith-lab-canonical-images   ◄── you are here   the images origin (service Dockerfiles)
loadsmith-lab-canonical-catalog                       the catalog origin (cases reference images/<name>)
loadsmith-lab-canonical-data                          the seed dataset, baked in at build time
loadsmith-lab                                          the engine (resolve, build, run)
```

A defining property of these images: **no CSV is committed here.** Each image's
Dockerfile generates the canonical seed data at build time from
[`loadsmith-lab-canonical-data`](https://loadsmith-el.github.io/loadsmith-lab-canonical-data/)
and bakes it in — see [Build-time Seed Data](./build-time-data.md).

## Where to go next

- [Layout & Manifest](./layout.md) — the directory shape and the manifest.
- [The Images](./images.md) — what ships today.
- [Build-time Seed Data](./build-time-data.md) — the multi-stage Dockerfile
  pattern.
- [CI & Registry](./ci-and-registry.md) — GHCR publishing, change detection, and
  the version-tag derivation.
- [Using the Images](./using.md) — registering the origin and building.
- [Adding an Image](./adding-an-image.md) — the rules for a new service image.
