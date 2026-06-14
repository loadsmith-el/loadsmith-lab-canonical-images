# Using the Images

Consumed by `loadsmith-lab` as an origin. For local development, register it as a
**local** origin — the lab reads it live, with no install step:

```bash
# Register once (local dev: read live from the working tree)
loadsmith-lab origin local add images ../loadsmith-lab-canonical-images

# Build an image explicitly
loadsmith-lab build --select images/lab-postgres-15
```

A case in
[`loadsmith-lab-canonical-catalog`](https://loadsmith-el.github.io/loadsmith-lab-canonical-catalog/)
references an image as `image: images/<name>`; it is **auto-built on first run**,
so you usually don't build images by hand.

## Forcing a rebuild

The runner reuses a cached `loadsmith-lab/images/<name>:local` image. After
changing a Dockerfile or `init.*`, force a rebuild:

```bash
docker rmi loadsmith-lab/images/<name>:local   # drop the stale cached build
loadsmith-lab build --select images/<name>
```
