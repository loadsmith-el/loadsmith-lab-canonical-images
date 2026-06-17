# lab-oracle TLS material (committed on purpose)

These files are a **throwaway, self-signed certificate chain** for the in-image
stunnel TLS terminator. They are committed deliberately — see
[`../README.md` § TLS](../README.md#tls--why-stunnel-and-why-a-committed-cert)
for the full rationale. In short: `oracle-rs` always verifies the server cert
(no encrypt-without-verify mode), so the connector must *trust* the cert at
case-authoring time, which means it can't be generated fresh per build the way
the postgres/mysql lab certs are.

| file         | what it is                          | used by                                    |
|--------------|-------------------------------------|--------------------------------------------|
| `ca.crt`     | self-signed lab CA (public)         | the case, as `tls.root_cert` (client pins) |
| `ca.key`     | CA private key                      | `gen-certs.sh` only (re-signing)           |
| `server.crt` | leaf cert, signed by the CA         | reference / regeneration                   |
| `server.key` | leaf private key                    | bundled into `server.pem`                  |
| `server.pem` | `server.crt` + `server.key`         | stunnel (`cert =`)                         |

A *single* self-signed cert does not work: rustls rejects a CA-flagged cert used
as the server leaf (`CaUsedAsEndEntity`). Hence the two-tier chain — the leaf
carries `CA:FALSE`, `serverAuth` EKU, and SANs (`oracle`, `localhost`,
`127.0.0.1`).

**Not a secret.** These keys protect nothing but a localhost lab container and
exist only so the lab can exercise certificate-pinned TLS. Repo secret scanners
will flag `*.key` / `server.pem`; that is expected and harmless.

## Regenerating (e.g. on expiry — 10-year validity)

```bash
cd images/lab-oracle/tls
./gen-certs.sh
```

The CA (`ca.crt`) changes on regeneration, so update the `tls.root_cert` block in
the `oracle-to-jsonl-tls` case to match (it embeds the CA inline).
