# Layout & Manifest

```text
loadsmith-lab.toml      manifest: name → description
images/<name>/
  Dockerfile             multi-stage: generates the seed CSV at build time, then bakes it in
  init.sql / init.*      schema + bulk load for the canonical dataset
```

The directory name **is** the item name (no prefix stripping). The lab builds it
under the local tag `loadsmith-lab/images/<name>:local`.

## Update the manifest

Adding an image means adding **both** `images/<name>/` *and* an entry under
`[images]` in `loadsmith-lab.toml`. `loadsmith-lab list` / `build` and
`origin show images` read the **manifest**, not the filesystem.

Keep the [The Images](./images.md) table (and the repo `README.md`) in sync.
