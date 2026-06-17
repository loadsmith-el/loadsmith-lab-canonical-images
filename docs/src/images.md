# The Images

| Image | Description |
|---|---|
| `lab-postgres-15` | Postgres 15 with the canonical `spacecraft_telemetry_events` seed data baked in |
| `lab-mysql-8` | MySQL 8 with the canonical `spacecraft_telemetry_events` seed data baked in. User `lab` uses `caching_sha2_password` (the default, and the only plugin in MySQL 9); `lab_native` uses the legacy `mysql_native_password` (MySQL 5.x) — so both connector auth paths are covered. Includes an empty `events_sink` table for destination cases. |

`lab-postgres-15` is the reference image and the template for any new one. It:

- bakes in the 100k-row canonical dataset (see
  [Build-time Seed Data](./build-time-data.md));
- recreates the canonical 34-column schema in its `init.sql` (the schema source
  of truth is
  [`loadsmith-lab-canonical-data`](https://loadsmith-el.github.io/loadsmith-lab-canonical-data/));
- supports optional SSL (rustls handshake testing) via `LOADSMITH_ENABLE_SSL`;
- uses uniform credentials `lab` / `lab` / `lab` (user / password / database).

More service images would extend lab coverage beyond the Postgres source — see
[Adding an Image](./adding-an-image.md).
