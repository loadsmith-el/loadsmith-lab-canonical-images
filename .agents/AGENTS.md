# AI Agent Guidelines — loadsmith-lab-canonical-images

> Source of truth for this repository, for any AI agent (Claude, Codex, Gemini,
> …). The root `CLAUDE.md` is only a pointer to this folder.

## Golden Rule (the `.agents/` folder prevails)

The `.agents/` folder is the source of truth. If existing code conflicts with
what is documented here, the documented standard prevails — surface the conflict
to the user before diverging.

## Authoring rule — how to extend this (all agents MUST follow)

This `.agents/` folder is the **single source of truth for every AI agent**
(Claude, Codex, Gemini, …) — not a reference copy. When you add or change agent
guidance, you MUST keep that truth here:

- **A new directive / convention / rule** → add it to **this file**
  (`.agents/AGENTS.md`). Do **not** put it in `CLAUDE.md` or any other per-agent
  file — those are pointers, not content.
- **A new skill / command** → write the real, agent-agnostic logic in
  **`.agents/skills/<name>.md`**. Then wire each agent's native entry point as a
  **thin stub** that only redirects here:
  - Claude: `.claude/commands/<name>.md` — keep its frontmatter (`description`,
    `argument-hint`, `allowed-tools`) so the slash command registers, then a body
    that says "read and follow `.agents/skills/<name>.md`".
  - Other agents: their own command/skill mechanism, with the same redirect.
- **Never** duplicate real instructions or skill logic into `CLAUDE.md` or into a
  stub. If a per-agent file ever starts holding real content, move it here and
  leave a pointer behind.
- Committed files stay in **English** (repo rule), even when chatting in another
  language.

These are **operating instructions only** — for what this repo is and how an
image is built, read [README.md](../README.md) and the
[loadsmith-lab docs](../../loadsmith-lab/docs/src), or the source itself. Don't
guess at "why" — go read it.

## Conventions

- **English only.** All artifacts committed to this repo — Dockerfiles, init
  scripts, commit messages, identifiers — must be in English, even when the
  user writes in Portuguese.
- **This repo is content only.** It's the `images` origin for
  [loadsmith-lab](../../loadsmith-lab) — no engine code lives here. The runner
  that resolves/builds these images lives in `../loadsmith-lab` (see
  [`image.rs`](../../loadsmith-lab/crates/loadsmith-lab-runner/src/image.rs)).
- **Update the manifest.** Adding an image means adding `images/<name>/` *and*
  an entry under `[images]` in [`loadsmith-lab.toml`](../loadsmith-lab.toml) —
  `loadsmith-lab list`/`build` and `origin show images` read the manifest, not
  the filesystem.
- **Version tag.** The CI publishes a `:<version>` tag resolved per image (see
  [README.md § CI & Registry](../README.md#ci--registry)): for a **service image**
  it's *derived* from the Dockerfile's `ARG DATA_REF` (→ `:data-<ref>`), so you
  don't hand-write it anywhere — just pin `DATA_REF`. `DATA_REF` is this image's
  independent choice of canonical-data revision (decoupled from the service
  base version); it must match a `loadsmith-lab-canonical-data` tag/`VERSION`.
  Only an image that versions on a *different* axis (e.g. the future engine
  image) ships an explicit `images/<name>/VERSION` file to override the
  derivation. Stamp the revision as `LABEL org.opencontainers.image.version` in
  the Dockerfile (mirror `lab-postgres-15`).
- **Multi-arch.** Loadsmith images are published for both `linux/amd64` and
  `linux/arm64` (AWS Graviton support). Base every image on something that
  publishes official `arm64` variants too (most do — `postgres`, `debian`,
  `python`, …).

## Hard rules — read before adding or changing an image

- **Never commit a CSV (or any large generated data file).** Every image's
  Dockerfile is **multi-stage**: a `data` stage clones
  [`loadsmith-lab-canonical-data`](../../loadsmith-lab-canonical-data) at a pinned
  `DATA_REF` and runs its `generate.py` (deterministic, stdlib-only), then
  `COPY --from=data ... events.csv` bakes the result into the final image.
  Mirror `images/lab-postgres-15/Dockerfile` exactly for the `data` stage.
- **Pin `DATA_REF` to a tag** for reproducible builds. `DATA_REPO`/`DATA_REF`
  are `ARG`s with sane defaults, overridable via `--build-arg` for local/offline
  builds.
- **Credentials are always `lab` / `lab` / `lab`** (user / password /
  database or index), set via the image's native env vars, so every case is
  uniform.
- **Empty string means NULL** in the canonical CSV — the init/load step must
  treat empty fields as NULL (e.g. Postgres `COPY ... WITH (NULL '')`).
- **The lab tars only this directory's files** (`Dockerfile`, `init.*`, …) as
  the build context — don't rely on anything outside `images/<name>/` being
  present at build time except what the `data` stage fetches itself.
- **No DuckDB, no Parquet, no apt-get for data tooling** — the canonical CSV is
  the universal input format; prefer the target service's native CSV bulk
  loader (`COPY`, `LOAD DATA INFILE`, `clickhouse-client --query`, etc.).

## CI

[`build-images.yml`](../.github/workflows/build-images.yml) builds and publishes
to GHCR (`ghcr.io/loadsmith-el/<name>`) only the `images/<name>/` directories
that changed in a push to `main` — see [README.md § CI &
Registry](../README.md#ci--registry). Don't expect a Dockerfile-only change to
trigger a rebuild of unrelated images. PRs run a push-less build of changed
images to validate them.

## Adding a new image

Use the `/create-source-image` Claude Code command (its real logic lives in
`../loadsmith-lab/.agents/skills/create-source-image.md`; Claude's stub entry
point is `../loadsmith-lab/.claude/commands/create-source-image.md`), or follow
[Adding Service Images](../../loadsmith-lab/docs/src/writing-cases/adding-service-images.md)
manually — both describe the multi-stage Dockerfile pattern and the matching
`init.sql` schema (34 columns, see
[`loadsmith-lab-canonical-data/README.md`](../../loadsmith-lab-canonical-data/README.md)).

## Verifying a change

This repo has no build step of its own — verify by building the image and
running its case through `loadsmith-lab` (sibling repo, registered as a local
origin):

```bash
cd ../loadsmith-lab
./target/debug/loadsmith-lab origin local add images ../loadsmith-lab-canonical-images   # once
./target/debug/loadsmith-lab build --select images/<name>
docker rmi loadsmith-lab/images/<name>:local   # force a rebuild after Dockerfile/init changes
./target/debug/loadsmith-lab build --select images/<name>
```
