# lab-oracle

Oracle Free (the [gvenzl/oracle-free](https://github.com/gvenzl/oci-oracle-free)
image) seeded with the canonical `spacecraft_telemetry_events` dataset, plus an
**stunnel TLS terminator** so the lab can exercise the Oracle connector's TCPS
(TLS) path.

- **Base:** `gvenzl/oracle-free:23-slim` (currently the 26ai engine, multi-arch
  amd64 + arm64). Default pluggable database `FREEPDB1`, app user `lab` / `lab`.
- **Seed:** `init.sql` loads the canonical CSV via an `ORACLE_LOADER` external
  table → `INSERT … SELECT` with explicit `TO_DATE`/`TO_TIMESTAMP`/`TO_NUMBER`
  conversions (the pure-SQL equivalent of postgres `COPY` / mysql `LOAD DATA`).
  The dataset is generated at build time from `loadsmith-lab-canonical-data`
  (never committed); CRLF is stripped to LF in the build so the external table
  uses a simple `RECORDS DELIMITED BY NEWLINE`.
- **Schema:** canonical 34 columns in 12c–19c-compatible Oracle dialect (the
  connector's supported range): `NUMBER(1)` for booleans (no native `BOOLEAN`
  before 23ai), `VARCHAR2(8)` for the `event_time` (no `TIME` type), and
  `BINARY_DOUBLE` for `reading_double` (to exercise that connector path).
  `events_sink` is the empty target table for the oracle-to-oracle cases.

## TLS — why stunnel, and why a committed cert

These are two **deliberate** design decisions. They're documented here (not just
in commit history) so nobody later "fixes" them without knowing the why.

### 1. The TLS endpoint is stunnel, not native Oracle TCPS

The connector's TLS path is validated against an **stunnel** terminator listening
on `2484` and forwarding plaintext TNS to `127.0.0.1:1521` inside the same
container (started by `01_stunnel.sh`, only when `LOADSMITH_ENABLE_TLS=on`).

Why not configure Oracle's own TCPS listener? Native TCPS requires a server-side
Oracle **wallet**, which can only be built with `orapki`/`mkstore`. **Every slim
Oracle image — gvenzl *and* the official `container-registry.oracle.com` "lite"
— strips `orapki` and the bundled JDK.** Building a wallet would force either the
~9 GB full official image (a punishing CI pull) or committing a pre-built Oracle
wallet. stunnel sidesteps all of that:

- Oracle TCPS *is* TNS-over-TLS. On Linux, Oracle hands the connection off via a
  direct socket pass (not a plaintext redirect), so terminating TLS at stunnel
  and forwarding the raw TNS stream is protocol-clean — verified end-to-end with
  the connector (rustls-rustcrypto handshake + encrypted TNS + query round-trip).
- The connector **cannot tell the difference**: it does the same rustls handshake
  and speaks TNS over the encrypted socket. The client-side TLS coverage is
  identical to native TCPS. Only the server-side terminator differs.

If a future image ever needs *native* server-side TCPS, it must base on the full
Oracle image and generate a wallet — a separate, heavier image, not this one.

### 2. The lab TLS cert is committed (verify-ca, not "encrypt-without-verify")

The postgres/mysql TLS cases use `tls.mode: require` — encrypt without verifying
the server cert — so those images generate a throwaway cert at runtime and commit
nothing. **`oracle-rs` has no encrypt-without-verify mode**: it always verifies
the server chain. So the Oracle TLS case uses `tls.mode: verify-ca` and the
client must *trust* the cert at case-authoring time — which means the cert has to
be known/committed, not generated fresh per build.

`tls/` therefore holds a **throwaway, self-signed lab CA + leaf cert**, committed
on purpose (see `tls/README.md`). The CA is pinned by the case via
`tls.root_cert`; stunnel presents the leaf. This is actually *stronger* coverage
than the postgres/mysql `require` cases — it exercises real certificate-chain
pinning. The committed private key is not a secret (it protects nothing but a
localhost lab container) but it will trip repo secret scanners; that's expected.

## Building / verifying

```bash
cd ../loadsmith-lab
./target/debug/loadsmith-lab build --select images/lab-oracle
# force a rebuild after Dockerfile/init changes:
docker rmi loadsmith-lab/images/lab-oracle:local
```
