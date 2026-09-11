#!/usr/bin/env bash
set -euo pipefail

# Disposable PG18 acceptance test for T13. It uses trust auth only inside two
# local containers, never a cloud endpoint. The containers are uniquely named
# and removed on exit; no repository or user container is touched.
command -v docker >/dev/null 2>&1 || { printf '%s\n' 'docker is required' >&2; exit 127; }
psql_bin=${PSQL_BIN:-}
if [[ -z $psql_bin ]]; then psql_bin=$(command -v psql || true); fi
[[ -n $psql_bin ]] || { printf '%s\n' 'psql 18 client is required (set PSQL_BIN)' >&2; exit 127; }

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

printf '[staging_owner]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=neondb_owner\n\n' "$staging_port" >"$service_file"
printf '[staging_app]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_staging_app\n\n' "$staging_port" >>"$service_file"
printf '[staging_migrator]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_staging_migrator\n\n' "$staging_port" >>"$service_file"
printf '[production_owner]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=neondb_owner\n\n' "$production_port" >>"$service_file"
printf '[production_app]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_production_app\n\n' "$production_port" >>"$service_file"
printf '[staging_on_production]\nhost=127.0.0.1\nport=%s\ndbname=neondb\nuser=greeniteso_staging_app\n' "$production_port" >>"$service_file"

export PATH="$(dirname "$psql_bin"):$PATH"
scripts/neon-role-apply.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" >/dev/null
scripts/neon-role-apply.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" >/dev/null
scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" >/dev/null
scripts/neon-role-apply.sh --environment production --service production_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$production_port" \
  --allow-production >/dev/null
scripts/neon-role-verify.sh --environment production --service production_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$production_port" >/dev/null

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
  -c 'CREATE ROLE app_role_must_fail;' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: app role created a role' >&2
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

printf '%s\n' 'PASS: PG18 roles, DML, DDL denial, default privileges, role/catalog isolation, and target binding (password auth remains a cloud check).'
