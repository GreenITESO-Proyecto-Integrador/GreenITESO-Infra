#!/usr/bin/env bash
set -euo pipefail

# Disposable PG18 SCRAM acceptance test for T13. This is separate from the
# trust-auth role contract test: every checked role connection here uses a
# password through a 0600 pg_service.conf entry, and no password is printed.
command -v docker >/dev/null 2>&1 || { printf '%s\n' 'docker is required' >&2; exit 127; }
command -v openssl >/dev/null 2>&1 || { printf '%s\n' 'openssl is required' >&2; exit 127; }
psql_bin=${PSQL_BIN:-}
if [[ -z $psql_bin ]]; then psql_bin=$(command -v psql || true); fi
[[ -n $psql_bin ]] || { printf '%s\n' 'psql 18 client is required (set PSQL_BIN)' >&2; exit 127; }
unset PGHOSTADDR PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD PGSERVICE PGSERVICEFILE

temp_dir=$(mktemp -d)
chmod 700 "$temp_dir"
service_file="$temp_dir/pg_service.conf"
: >"$service_file"
chmod 600 "$service_file"
staging_container="greeniteso-roles-scram-staging-${PPID}_${RANDOM}"
production_container="greeniteso-roles-scram-production-${PPID}_${RANDOM}"
staging_port=''
production_port=''

cleanup() {
  docker rm -f "$staging_container" "$production_container" >/dev/null 2>&1 || true
  if [[ -n ${temp_dir:-} && -d $temp_dir ]]; then rm -rf -- "$temp_dir"; fi
}
trap cleanup EXIT

random_secret() { openssl rand -hex 24; }

start_pg() {
  local container=$1
  local env_file=$2
  docker run -d --name "$container" --env-file "$env_file" \
    -e POSTGRES_DB=neondb -e POSTGRES_HOST_AUTH_METHOD=scram-sha-256 \
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

staging_postgres_password=$(random_secret)
production_postgres_password=$(random_secret)
staging_owner_password=$(random_secret)
production_owner_password=$(random_secret)
staging_app_password=$(random_secret)
production_app_password=$(random_secret)
staging_migrator_password=$(random_secret)
production_migrator_password=$(random_secret)
staging_wrong_password=$(random_secret)
if [[ $staging_app_password == "$staging_migrator_password" \
  || $production_app_password == "$production_migrator_password" ]]; then
  printf '%s\n' 'FAIL: generated app and migrator passwords were not distinct' >&2
  exit 1
fi

staging_env="$temp_dir/staging.env"
production_env="$temp_dir/production.env"
printf 'POSTGRES_PASSWORD=%s\n' "$staging_postgres_password" >"$staging_env"
printf 'POSTGRES_PASSWORD=%s\n' "$production_postgres_password" >"$production_env"
chmod 600 "$staging_env" "$production_env"

staging_port=$(start_pg "$staging_container" "$staging_env")
production_port=$(start_pg "$production_container" "$production_env")

bootstrap_container() {
  local port=$1
  local postgres_password=$2
  local owner_password=$3
  local bootstrap_sql="$temp_dir/bootstrap-${port}.sql"
  cat >"$bootstrap_sql" <<SQL
CREATE ROLE neondb_owner LOGIN CREATEDB CREATEROLE PASSWORD '$owner_password';
ALTER DATABASE neondb OWNER TO neondb_owner;
SQL
  chmod 600 "$bootstrap_sql"
  PGPASSWORD="$postgres_password" PGSSLMODE=disable "$psql_bin" -h 127.0.0.1 -p "$port" \
    -U postgres -d neondb -v ON_ERROR_STOP=1 -f "$bootstrap_sql" >/dev/null
}

bootstrap_container "$staging_port" "$staging_postgres_password" "$staging_owner_password"
bootstrap_container "$production_port" "$production_postgres_password" "$production_owner_password"

cat >"$service_file" <<EOF
[staging_owner]
host=127.0.0.1
port=$staging_port
dbname=neondb
user=neondb_owner
password=$staging_owner_password
connect_timeout=5

[staging_app]
host=127.0.0.1
port=$staging_port
dbname=neondb
user=greeniteso_staging_app
password=$staging_app_password
connect_timeout=5

[staging_migrator]
host=127.0.0.1
port=$staging_port
dbname=neondb
user=greeniteso_staging_migrator
password=$staging_migrator_password
connect_timeout=5

[production_owner]
host=127.0.0.1
port=$production_port
dbname=neondb
user=neondb_owner
password=$production_owner_password
connect_timeout=5

[production_app]
host=127.0.0.1
port=$production_port
dbname=neondb
user=greeniteso_production_app
password=$production_app_password
connect_timeout=5

[production_migrator]
host=127.0.0.1
port=$production_port
dbname=neondb
user=greeniteso_production_migrator
password=$production_migrator_password
connect_timeout=5

[staging_app_wrong_password]
host=127.0.0.1
port=$staging_port
dbname=neondb
user=greeniteso_staging_app
password=$staging_wrong_password
connect_timeout=5

[staging_app_on_production]
host=127.0.0.1
port=$production_port
dbname=neondb
user=greeniteso_staging_app
password=$staging_app_password
connect_timeout=5
EOF
chmod 600 "$service_file"

export PATH="$(dirname "$psql_bin"):$PATH"
scripts/neon-role-apply.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" \
  --local-test >/dev/null
scripts/neon-role-apply.sh --environment production --service production_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$production_port" \
  --allow-production --local-test >/dev/null

staging_credentials_sql="$temp_dir/staging-role-passwords.sql"
production_credentials_sql="$temp_dir/production-role-passwords.sql"
cat >"$staging_credentials_sql" <<SQL
ALTER ROLE greeniteso_staging_app PASSWORD '$staging_app_password';
ALTER ROLE greeniteso_staging_migrator PASSWORD '$staging_migrator_password';
SQL
cat >"$production_credentials_sql" <<SQL
ALTER ROLE greeniteso_production_app PASSWORD '$production_app_password';
ALTER ROLE greeniteso_production_migrator PASSWORD '$production_migrator_password';
SQL
chmod 600 "$staging_credentials_sql" "$production_credentials_sql"
PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_owner \
  -v ON_ERROR_STOP=1 -f "$staging_credentials_sql" >/dev/null
PGSERVICEFILE="$service_file" "$psql_bin" -X service=production_owner \
  -v ON_ERROR_STOP=1 -f "$production_credentials_sql" >/dev/null

scripts/neon-role-verify.sh --environment staging --service staging_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$staging_port" \
  --local-test >/dev/null
scripts/neon-role-verify.sh --environment production --service production_owner \
  --service-file "$service_file" --expected-host 127.0.0.1 --expected-port "$production_port" \
  --local-test >/dev/null

staging_app_user=$(PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -Atqc \
  'SELECT current_user;')
staging_migrator_user=$(PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_migrator -Atqc \
  'SELECT current_user;')
production_app_user=$(PGSERVICEFILE="$service_file" "$psql_bin" -X service=production_app -Atqc \
  'SELECT current_user;')
production_migrator_user=$(PGSERVICEFILE="$service_file" "$psql_bin" -X service=production_migrator -Atqc \
  'SELECT current_user;')
[[ $staging_app_user == greeniteso_staging_app ]] || {
  printf 'FAIL: SCRAM app authentication returned unexpected role (%s)\n' "$staging_app_user" >&2
  exit 1
}
[[ $staging_migrator_user == greeniteso_staging_migrator ]] || {
  printf 'FAIL: SCRAM migrator authentication returned unexpected role (%s)\n' "$staging_migrator_user" >&2
  exit 1
}
[[ $production_app_user == greeniteso_production_app ]] || {
  printf 'FAIL: SCRAM production app authentication returned unexpected role (%s)\n' "$production_app_user" >&2
  exit 1
}
[[ $production_migrator_user == greeniteso_production_migrator ]] || {
  printf 'FAIL: SCRAM production migrator authentication returned unexpected role (%s)\n' "$production_migrator_user" >&2
  exit 1
}

PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_migrator -v ON_ERROR_STOP=1 \
  -c 'CREATE TABLE scram_probe (id integer PRIMARY KEY, payload text NOT NULL);' >/dev/null
PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c "INSERT INTO scram_probe VALUES (1, 'scram-dml-ok'); SELECT count(*) FROM scram_probe;" >/dev/null
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app -v ON_ERROR_STOP=1 \
  -c 'CREATE TABLE scram_app_ddl_must_fail (id integer);' >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: SCRAM app role executed DDL' >&2
  exit 1
fi
wrong_password_stderr="$temp_dir/wrong-password.stderr"
: >"$wrong_password_stderr"
chmod 600 "$wrong_password_stderr"
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app_wrong_password \
  -c 'SELECT 1;' > /dev/null 2>"$wrong_password_stderr"; then
  printf '%s\n' 'FAIL: SCRAM authentication accepted a wrong password' >&2
  exit 1
fi
if ! grep -Fq 'password authentication failed' "$wrong_password_stderr"; then
  printf '%s\n' 'FAIL: wrong-password check did not reach PostgreSQL authentication' >&2
  exit 1
fi
cross_environment_stderr="$temp_dir/cross-environment.stderr"
: >"$cross_environment_stderr"
chmod 600 "$cross_environment_stderr"
if PGSERVICEFILE="$service_file" "$psql_bin" -X service=staging_app_on_production \
  -c 'SELECT 1;' > /dev/null 2>"$cross_environment_stderr"; then
  printf '%s\n' 'FAIL: staging SCRAM credential authenticated on production fixture' >&2
  exit 1
fi
if ! grep -Fq 'password authentication failed' "$cross_environment_stderr"; then
  printf '%s\n' 'FAIL: cross-environment check did not reach PostgreSQL authentication' >&2
  exit 1
fi

printf '%s\n' 'PASS: PG18 SCRAM authentication, distinct app/migrator passwords, DML, DDL denial, wrong-password rejection, and cross-environment isolation (local proof only).'
