# Neon app-role smoke — 2026-09-25

Read-only verification from a local macOS process using the unpublished
Backend PR30 worktree at `822ba01` (`db_smoke --timeout 15 --check-grants`).
This is not evidence of a Cloud Run deployment or of a migration being run by
the new release workflow. No DDL, DML, seed or production connection occurred.

| Neon branch | Connection | Result | Grants checked |
| --- | --- | --- | --- |
| `dev` | pooled `greeniteso_dev_app`, TLS `verify-full` | `DB_SMOKE OK`; User=0, ActionLog=0; client SSL active | 23 public tables, 9 sequences; DDL denied |
| `staging` | pooled `greeniteso_staging_app`, TLS `verify-full` | `DB_SMOKE OK`; User=0, ActionLog=0; client SSL active | 23 public tables, 9 sequences; DDL denied |

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
