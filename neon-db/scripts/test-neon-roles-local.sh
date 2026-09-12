#!/usr/bin/env bash
set -euo pipefail

# Disposable PG18 acceptance test for T13. It uses trust auth only inside two
# local containers, never a cloud endpoint. The containers are uniquely named
# and removed on exit; no repository or user container is touched.
command -v docker >/dev/null 2>&1 || { printf '%s\n' 'docker is required' >&2; exit 127; }
psql_bin=${PSQL_BIN:-}
if [[ -z $psql_bin ]]; then psql_bin=$(command -v psql || true); fi
[[ -n $psql_bin ]] || { printf '%s\n' 'psql 18 client is required (set PSQL_BIN)' >&2; exit 127; }
# This script is the explicit local-test mode; keep inherited libpq routing
# variables from redirecting its direct loopback checks.
unset PGHOSTADDR PGHOST PGPORT PGDATABASE PGUSER PGSERVICE

suffix="${PPID}_${RANDOM}"
staging_container="greeniteso-roles-staging-${suffix}"
production_container="greeniteso-roles-production-${suffix}"
staging_port=''
production_port=''
service_file=$(mktemp)
chmod 600 "$service_file"

cleanup() {
  docker rm -f "$staging_container" "$production_container" >/dev/null 2>&1 || true
  if [[ -n ${service_file:-} && -e $service_file ]]; then rm -f -- "$service_file"; fi
}
trap cleanup EXIT

start_pg() {
  local container=$1
  docker run -d --name "$container" \
    -e POSTGRES_DB=neondb \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -p 127.0.0.1::5432 postgres:18 >/dev/null
  local port
  port=$(docker port "$container" 5432/tcp | sed -E 's/.*:([0-9]+)$/\1/')
  for _ in $(seq 1 60); do
    if docker exec "$container" pg_isready -U postgres -d neondb >/dev/null 2>&1; then
      printf '%s\n' "$port"
      return 0
    fi
    sleep 1
  done
  printf 'PostgreSQL did not become ready: %s\n' "$container" >&2
  return 1
}

staging_port=$(start_pg "$staging_container")
production_port=$(start_pg "$production_container")

# Use a CREATEROLE database owner, matching the Neon owner/membership path;
# the bootstrap scripts must not depend on a local superuser connection.
for port in "$staging_port" "$production_port"; do
  "$psql_bin" -h 127.0.0.1 -p "$port" -U postgres -d neondb -v ON_ERROR_STOP=1 \
    -c 'CREATE ROLE neondb_owner LOGIN CREATEDB CREATEROLE; ALTER DATABASE neondb OWNER TO neondb_owner;'
done

# Seed a pre-existing owner membership and relation in staging. Bootstrap must
# preserve both while still configuring defaults for the migrator role.
"$psql_bin" -h 127.0.0.1 -p "$staging_port" -U postgres -d neondb -v ON_ERROR_STOP=1 \
  -c 'CREATE ROLE greeniteso_staging_migrator LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; GRANT greeniteso_staging_migrator TO neondb_owner WITH SET TRUE;'
"$psql_bin" -h 127.0.0.1 -p "$staging_port" -U neondb_owner -d neondb -v ON_ERROR_STOP=1 \
  -c 'CREATE TABLE owner_probe (id integer PRIMARY KEY, payload text NOT NULL); CREATE ROLE audit_probe NOLOGIN; GRANT SELECT ON owner_probe TO audit_probe;'

printf '[staging_owner]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=neondb_owner\n\n' "$staging_port" >"$service_file"
printf '[staging_app]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_staging_app\n\n' "$staging_port" >>"$service_file"
printf '[staging_migrator]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_staging_migrator\n\n' "$staging_port" >>"$service_file"
printf '[production_owner]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=neondb_owner\n\n' "$production_port" >>"$service_file"
printf '[production_app]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_production_app\n\n' "$production_port" >>"$service_file"
printf '[production_migrator]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_production_migrator\n\n' "$production_port" >>"$service_file"
printf '[staging_on_production]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_staging_app\n' "$production_port" >>"$service_file"
printf '[hostaddr_env_bypass]\nhost=branch-label.invalid\nport=%s\ndbname=neondb\nuser=neondb_owner\n\n' "$staging_port" >>"$service_file"
printf '[hostaddr_service_bypass]\nhost=branch-label.invalid\nhostaddr=127.0.0.1\nport=%s\ndbname=neondb\nuser=neondb_owner\n' "$staging_port" >>"$service_file"
printf '[cloud_wrong_endpoint]\nhost=ep-old-salad-axvsz82z.us-east-2.aws.neon.tech\nport=5432\ndbname=neondb\nuser=neondb_owner\nsslmode=require\n\n' >>"$service_file"
printf '[cloud_pooler]\nhost=ep-lively-brook-ax4n0pys-pooler.us-east-2.aws.neon.tech\nport=5432\ndbname=neondb\nuser=neondb_owner\nsslmode=require\n\n' >>"$service_file"
printf '[cloud_no_tls]\nhost=ep-lively-brook-ax4n0pys.us-east-2.aws.neon.tech\nport=5432\ndbname=neondb\nuser=neondb_owner\nsslmode=disable\n' >>"$service_file"

export PATH="$(dirname "$psql_bin"):$PATH"
chmod 644 "$service_file"
if scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --local-test >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: verifier accepted an insecure service file' >&2
  exit 1
fi
chmod 600 "$service_file"
if scripts/neon-role-apply.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --local-test >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: existing owner objects bypassed the explicit ownership gate' >&2
  exit 1
fi
scripts/neon-role-apply.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --allow-existing-owners --local-test >/dev/null
scripts/neon-role-apply.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --allow-existing-owners --local-test >/dev/null
if scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --local-test >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: verifier accepted a relation still owned by the pre-existing owner' >&2
  exit 1
fi
if scripts/neon-role-verify.sh --environment staging --service staging_app \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --local-test >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role executed administrative verification' >&2
  exit 1
fi
if scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" \
  --database postgres --local-test >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: verifier accepted a mislabeled database' >&2
  exit 1
fi
"$psql_bin" -h 127.0.0.1 -p "$production_port" -U postgres -d neondb -v ON_ERROR_STOP=1 \
  -c 'CREATE ROLE greeniteso_production_migrator LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; GRANT greeniteso_production_migrator TO neondb_owner WITH INHERIT TRUE, SET FALSE, ADMIN TRUE;' >/dev/null
scripts/neon-role-apply.sh --environment production --service production_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$production_port" \
  --allow-production --local-test >/dev/null
scripts/neon-role-verify.sh --environment production --service production_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$production_port" --local-test >/dev/null
production_membership=$($psql_bin -h 127.0.0.1 -p "$production_port" -U postgres -d neondb -Atqc \
  "SELECT inherit_option || '|' || set_option || '|' || admin_option FROM pg_auth_members membership JOIN pg_roles member ON member.oid = membership.member JOIN pg_roles granted_role ON granted_role.oid = membership.roleid WHERE member.rolname = 'neondb_owner' AND granted_role.rolname = 'greeniteso_production_migrator';")
[[ $production_membership == 'true|false|true' ]] || {
  printf 'FAIL: ADMIN TRUE/SET FALSE owner membership was not preserved (%s)\n' "$production_membership" >&2
  exit 1
}
app_idle_timeout=$(PGSERVICEFILE="$service_file" "$psql_bin" -X service=production_app -Atqc \
  "SELECT current_setting('idle_in_transaction_session_timeout')::interval = interval '60 seconds';")
[[ $app_idle_timeout == t ]] || {
  printf 'FAIL: app idle transaction timeout was not 60 seconds (%s)\n' "$app_idle_timeout" >&2
  exit 1
}
migrator_lock_timeout=$(PGSERVICEFILE="$service_file" "$psql_bin" -X service=production_migrator -Atqc \
  "SELECT current_setting('lock_timeout')::interval = interval '5 seconds';")
[[ $migrator_lock_timeout == t ]] || {
  printf 'FAIL: migrator lock timeout was not 5 seconds (%s)\n' "$migrator_lock_timeout" >&2
  exit 1
}

PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_migrator -v ON_ERROR_STOP=1 \
  -c 'CREATE TABLE role_probe (id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, payload text NOT NULL);'
PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c "INSERT INTO role_probe (payload) VALUES ('dml-ok'); SELECT count(*) AS app_rows FROM role_probe;"

if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c 'CREATE TABLE app_ddl_must_fail (id integer);' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role executed DDL' >&2
  exit 1
fi
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c 'ALTER TABLE role_probe ADD COLUMN app_ddl_must_fail integer;' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role altered a table' >&2
  exit 1
fi
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c 'DROP TABLE role_probe;' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role dropped a table' >&2
  exit 1
fi
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c 'CREATE TEMP TABLE app_temp_must_fail (id integer);' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role created a temporary table' >&2
  exit 1
fi
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c 'CREATE ROLE app_role_must_fail;' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role created a role' >&2
  exit 1
fi

owner_probe_owner=$("$psql_bin" -h 127.0.0.1 -p "$staging_port" -U postgres -d neondb -Atqc \
  "SELECT owner_role.rolname FROM pg_class relation JOIN pg_roles owner_role ON owner_role.oid = relation.relowner WHERE relation.relname = 'owner_probe';")
[[ $owner_probe_owner == neondb_owner ]] || {
  printf 'FAIL: existing owner_probe ownership changed (%s)\n' "$owner_probe_owner" >&2
  exit 1
}
owner_membership=$("$psql_bin" -h 127.0.0.1 -p "$staging_port" -U postgres -d neondb -Atqc \
  "SELECT count(*) FROM pg_auth_members membership JOIN pg_roles member ON member.oid = membership.member JOIN pg_roles granted_role ON granted_role.oid = membership.roleid WHERE member.rolname = 'neondb_owner' AND granted_role.rolname = 'greeniteso_staging_migrator' AND membership.set_option;")
[[ $owner_membership == 1 ]] || {
  printf 'FAIL: pre-existing owner membership was not preserved (%s)\n' "$owner_membership" >&2
  exit 1
}
audit_privilege=$("$psql_bin" -h 127.0.0.1 -p "$staging_port" -U postgres -d neondb -Atqc \
  "SELECT has_table_privilege('audit_probe', 'public.owner_probe', 'SELECT');")
[[ $audit_privilege == t ]] || {
  printf 'FAIL: unrelated existing table ACL was not preserved (%s)\n' "$audit_privilege" >&2
  exit 1
}
"$psql_bin" -h 127.0.0.1 -p "$staging_port" -U postgres -d neondb -v ON_ERROR_STOP=1 \
  -c 'GRANT REFERENCES ON owner_probe TO greeniteso_staging_app WITH GRANT OPTION;' >/dev/null
if scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" --local-test >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: verifier accepted an extra app relation grant option' >&2
  exit 1
fi

# The staging role was never created in the production branch/container, so a
# staging credential cannot authenticate there. This local trust-auth check
# proves role/catalog isolation; the cloud runbook separately requires a real
# password-auth connection check after Secret Manager assignment.
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_on_production \
  -c 'SELECT 1;' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: staging role connected to production' >&2
  exit 1
fi

# Expected-host/port binding must reject a service that points to another
# branch endpoint even when the environment label says staging.
if scripts/neon-role-verify.sh --environment staging --service staging_on_production \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: target binding accepted the production port' >&2
  exit 1
fi

# NOINHERIT membership can still permit SET ROLE escalation. Verification
# must reject this even when inherited schema privileges appear harmless.
"$psql_bin" "postgresql://postgres@127.0.0.1:${staging_port}/neondb" -v ON_ERROR_STOP=1 \
  -c 'CREATE ROLE escalation_probe NOLOGIN; GRANT CREATE ON SCHEMA public TO escalation_probe; GRANT escalation_probe TO greeniteso_staging_app WITH INHERIT FALSE, SET TRUE;' >/dev/null
if scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: verifier accepted SET ROLE escalation through NOINHERIT membership' >&2
  exit 1
fi

# The wrapper must not accept a routing address supplied by libpq's environment
# or hidden in the service entry while the visible host matches the expectation.
if PGSERVICEFILE="$service_file" PGHOSTADDR=127.0.0.1 scripts/neon-role-verify.sh \
  --environment staging --service hostaddr_env_bypass --service-file "$service_file" \
  --expected-host branch-label.invalid --expected-port "$staging_port" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: target binding accepted PGHOSTADDR override' >&2
  exit 1
fi
if PGSERVICEFILE="$service_file" PGHOSTADDR=127.0.0.1 scripts/neon-role-apply.sh \
  --environment staging --service hostaddr_env_bypass --service-file "$service_file" \
  --expected-host branch-label.invalid --expected-port "$staging_port" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: apply target binding accepted PGHOSTADDR override' >&2
  exit 1
fi
if scripts/neon-role-verify.sh --environment staging --service hostaddr_service_bypass \
  --service-file "$service_file" --expected-host branch-label.invalid --expected-port "$staging_port" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: target binding accepted service hostaddr override' >&2
  exit 1
fi
if scripts/neon-role-apply.sh --environment staging --service hostaddr_service_bypass \
  --service-file "$service_file" --expected-host branch-label.invalid --expected-port "$staging_port" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: apply target binding accepted service hostaddr override' >&2
  exit 1
fi
if scripts/neon-role-verify.sh --environment staging --service cloud_wrong_endpoint \
  --service-file "$service_file" --expected-host ep-old-salad-axvsz82z.us-east-2.aws.neon.tech --expected-port 5432 >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: cloud verifier accepted a noncanonical staging endpoint' >&2
  exit 1
fi
if scripts/neon-role-verify.sh --environment dev --service cloud_pooler \
  --service-file "$service_file" --expected-host ep-lively-brook-ax4n0pys-pooler.us-east-2.aws.neon.tech --expected-port 5432 >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: cloud verifier accepted a pooled endpoint' >&2
  exit 1
fi
if scripts/neon-role-verify.sh --environment dev --service cloud_no_tls \
  --service-file "$service_file" --expected-host ep-lively-brook-ax4n0pys.us-east-2.aws.neon.tech --expected-port 5432 >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: cloud verifier accepted a non-TLS endpoint' >&2
  exit 1
fi

printf '%s\n' 'PASS: PG18 roles, DML, DDL denial, default privileges, owner preservation, role/catalog isolation, admin/database guards, and target binding (password auth remains a cloud check).'
