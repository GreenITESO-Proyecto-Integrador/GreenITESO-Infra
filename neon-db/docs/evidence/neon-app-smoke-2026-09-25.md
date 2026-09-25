# Neon app-role smoke — 2026-09-25

Read-only verification from a local macOS process using Backend commit
`822ba01457e87851aa5a3cc126e2e4b364b346fe` (`db_smoke --timeout 15
--check-grants`). At the time of this check the commit was **unpublished**,
an indirect descendant of Backend PR30's then-remote head
`c4ec42467cba7f0a3393f93b944cd114fec179b4`: the local chain merged
Backend `dev` at `4f8b4dc`, added the grant check at `e41391c`, the managed
table inventory at `f44f1e5`, and the promotion evidence gate at `822ba01`.
It was later published as an ancestor of PR30 head
`8c7da3b4f22b0e14751ddee503ffe7f4b1ccd063`. This evidence records the
locally tested code, not a GitHub run.
This is not evidence of a Cloud Run deployment or of a migration being run by
the new release workflow. No DDL, DML, seed or production connection occurred.

| Neon branch | Connection | Result | Grants checked |
| --- | --- | --- | --- |
| `dev` | pooled `greeniteso_dev_app`, TLS `verify-full` | `DB_SMOKE OK`; User=0, ActionLog=0; client SSL active | 23 public tables, 9 sequences; CREATE/TRUNCATE privilege absent |
| `staging` | pooled `greeniteso_staging_app`, TLS `verify-full` | `DB_SMOKE OK`; User=0, ActionLog=0; client SSL active | 23 public tables, 9 sequences; CREATE/TRUNCATE privilege absent |

The new check requires every managed Django model table (including
auto-created M2M tables) to exist, then verifies SELECT/INSERT/UPDATE/DELETE
grants on all public tables, sequence USAGE, schema USAGE, and denial of
schema CREATE and table TRUNCATE. The check is executed in a read-only
transaction and does not try a write. Existing Infra evidence separately
records controlled DDL denial and cross-environment authentication denial.

On this macOS host, the Neon CLI connection string with `sslmode=verify-full`
alone was not enough for libpq: the client reported a missing root certificate
file. An explicit `sslrootcert=/etc/ssl/cert.pem` made the local psycopg
connection and smoke pass. That path is **host-specific**; the deployment
must supply a trusted CA path or validated system trust configuration, not
copy this macOS path into GitHub or Cloud Run secrets. URLs, passwords,
certificates and the internal `neon_auth` configuration were not recorded.

Production role and migration/rollback remain unverified. The release
workflow is still a draft PR and was not invoked for this smoke.
