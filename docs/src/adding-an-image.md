# Adding an Image

The walkthrough of the multi-stage Dockerfile pattern and the matching `init.sql`
schema lives in the lab docs:
[Adding Service Images](https://loadsmith-el.github.io/loadsmith-lab/writing-cases/adding-service-images.html).
There's also a `/create-source-image` Claude Code command in the lab repo
(`.claude/commands/create-source-image.md`).

What follows are the rules specific to **this** content repo.

## Checklist

1. Create `images/<name>/` with a **multi-stage Dockerfile** — copy
   `images/lab-postgres-15/Dockerfile`'s `data` stage exactly (clone
   [`loadsmith-lab-canonical-data`](https://loadsmith-el.github.io/loadsmith-lab-canonical-data/)
   at a pinned `DATA_REF`, run `generate.py`, `COPY --from=data`).
2. Write `init.*` that recreates the **canonical 34-column schema** in the target
   service's dialect and bulk-loads the CSV (header row present, empty = NULL).
3. Set credentials to `lab` / `lab` / `lab` via the image's native env vars.
4. Stamp the data revision as `LABEL org.opencontainers.image.version` (mirror
   `lab-postgres-15`).
5. Add an entry under `[images]` in `loadsmith-lab.toml`, and update the
   [The Images](./images.md) table + `README.md`.

## Hard rules

- **Multi-arch.** Base every image on something that publishes official `arm64`
  variants too (`postgres`, `debian`, `python`, … most do). Loadsmith images are
  published for both `linux/amd64` and `linux/arm64` (AWS Graviton).
- **Version tag.** A service image's `:<version>` is *derived* from `ARG
  DATA_REF` (→ `:data-<ref>`) — don't hand-write it; just pin `DATA_REF` to a
  `loadsmith-lab-canonical-data` tag/`VERSION`. Only an image versioning on a
  *different* axis ships an explicit `images/<name>/VERSION` file to override the
  derivation. See [CI & Registry](./ci-and-registry.md).
- The build-time data rules in [Build-time Seed Data](./build-time-data.md) apply
  to every image — never commit a CSV, treat empty as NULL, no extra data
  tooling.

## Verifying a change

This repo has no build step of its own — verify by building the image and running
its case through `loadsmith-lab` (registered as a local origin):

```bash
cd ../loadsmith-lab
./target/debug/loadsmith-lab origin local add images ../loadsmith-lab-canonical-images   # once
./target/debug/loadsmith-lab build --select images/<name>
docker rmi loadsmith-lab/images/<name>:local   # force a rebuild after Dockerfile/init changes
./target/debug/loadsmith-lab build --select images/<name>
```
