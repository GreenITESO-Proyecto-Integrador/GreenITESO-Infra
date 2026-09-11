#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: neon-role-verify.sh --environment dev|staging|production \
  --service PGSERVICE --service-file FILE --expected-host HOST --expected-port PORT \
  [--database DATABASE] [--schema SCHEMA] [--local-test]

Run read-only role, schema, and default-privilege checks through pg_service.conf.
No password is accepted on the command line or printed.
EOF
}

environment=''
service=''
service_file=''
expected_host=''
expected_port=''
database='neondb'
schema='public'
local_test=0
while (($#)); do
  case "$1" in
    --environment) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; environment=$2; shift 2 ;;
    --service) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; service=$2; shift 2 ;;
    --service-file) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; service_file=$2; shift 2 ;;
    --expected-host) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; expected_host=$2; shift 2 ;;
    --expected-port) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; expected_port=$2; shift 2 ;;
    --database) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; database=$2; shift 2 ;;
    --schema) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; schema=$2; shift 2 ;;
    --local-test) local_test=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $environment =~ ^(dev|staging|production)$ ]] || { printf '%s\n' 'environment must be dev, staging, or production' >&2; exit 2; }
[[ -n $service && $service =~ ^[A-Za-z0-9_.-]+$ ]] || { printf '%s\n' 'a pg_service name is required' >&2; exit 2; }
[[ -n $service_file && -f $service_file && ! -L $service_file && -r $service_file && -O $service_file ]] || {
  printf '%s\n' 'a readable regular pg_service file owned by the current user is required' >&2
  exit 2
}
service_mode=''
if service_mode=$(stat -f '%Lp' "$service_file" 2>/dev/null); then :; else service_mode=''; fi
if ! [[ $service_mode =~ ^[0-7]{3,4}$ ]]; then
  service_mode=$(stat -c '%a' "$service_file" 2>/dev/null || true)
fi
[[ $service_mode =~ ^[0-7]{3,4}$ ]] || { printf '%s\n' 'could not inspect pg_service file permissions' >&2; exit 2; }
service_perms=$((8#$service_mode))
(( (service_perms & 077) == 0 )) || { printf '%s\n' 'pg_service file must not be group/world readable' >&2; exit 2; }
[[ -n $expected_host && $expected_host =~ ^[A-Za-z0-9_.:-]+$ ]] || { printf '%s\n' 'an expected branch endpoint host is required' >&2; exit 2; }
[[ $expected_port =~ ^[0-9]+$ && $expected_port -ge 1 && $expected_port -le 65535 ]] || { printf '%s\n' 'an expected endpoint port is required' >&2; exit 2; }
[[ $database =~ ^[A-Za-z_][A-Za-z0-9_]*$ && $schema =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { printf '%s\n' 'database and schema must be unquoted identifiers' >&2; exit 2; }
command -v psql >/dev/null 2>&1 || { printf '%s\n' 'psql is required' >&2; exit 127; }
service_host=$(awk -v section="[$service]" '
  $0 == section { in_section=1; next }
  /^\[/ { in_section=0 }
  in_section && $0 ~ /^[[:space:]]*host[[:space:]]*=/ {
    sub(/^[[:space:]]*host[[:space:]]*=[[:space:]]*/, ""); print; exit
  }
' "$service_file")
[[ -n $service_host ]] || { printf '%s\n' 'pg_service entry must contain an explicit host' >&2; exit 2; }
[[ $service_host == "$expected_host" ]] || {
  printf 'refusing target: service host does not match expected branch host (%s)\n' "$expected_host" >&2
  exit 3
}
service_port=$(awk -v section="[$service]" '
  $0 == section { in_section=1; next }
  /^\[/ { in_section=0 }
  in_section && $0 ~ /^[[:space:]]*port[[:space:]]*=/ {
    sub(/^[[:space:]]*port[[:space:]]*=[[:space:]]*/, ""); print; exit
  }
' "$service_file")
[[ $service_port == "$expected_port" ]] || {
  printf 'refusing target: service port does not match expected branch endpoint (%s)\n' "$expected_port" >&2
  exit 3
}
if awk -v section="[$service]" '
  $0 == section { in_section=1; next }
  /^\[/ { in_section=0 }
  in_section && tolower($0) ~ /^[[:space:]]*hostaddr[[:space:]]*=/ { found=1; exit }
  END { exit(found ? 0 : 1) }
' "$service_file"; then
  printf '%s\n' 'refusing target: pg_service entry must not contain hostaddr' >&2
  exit 3
fi
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
canonical_endpoint_id=$(awk -v environment="$environment" '$1 == environment { print $3; exit }' \
  "$script_dir/../config/neon-endpoints.tsv")
[[ -n $canonical_endpoint_id ]] || { printf '%s\n' 'environment has no canonical endpoint inventory entry' >&2; exit 2; }
canonical_endpoint_host=$(awk -v environment="$environment" '$1 == environment { print $4; exit }' \
  "$script_dir/../config/neon-endpoints.tsv")
[[ -n $canonical_endpoint_host ]] || { printf '%s\n' 'environment has no canonical direct hostname inventory entry' >&2; exit 2; }
service_sslmode=$(awk -v section="[$service]" '
  $0 == section { in_section=1; next }
  /^\[/ { in_section=0 }
  in_section && tolower($0) ~ /^[[:space:]]*sslmode[[:space:]]*=/ {
    sub(/^[[:space:]]*sslmode[[:space:]]*=[[:space:]]*/, ""); print; exit
  }
' "$service_file")
if (( local_test )); then
  [[ $service_host == 127.* || $service_host == '::1' || $service_host == localhost ]] || {
    printf '%s\n' '--local-test requires a loopback service host' >&2
    exit 2
  }
else
  service_host_lower=$(printf '%s' "$service_host" | tr '[:upper:]' '[:lower:]')
  [[ $service_host == *.* && $service_host_lower != *-pooler* && $service_host != 127.* && $service_host != localhost && $service_host != ::1 ]] || {
    printf '%s\n' 'cloud role operations require a direct non-loopback hostname' >&2
    exit 2
  }
  [[ $service_host == "$canonical_endpoint_host" ]] || {
    printf 'refusing target: service host is not the canonical %s endpoint (%s)\n' "$environment" "$canonical_endpoint_host" >&2
    exit 3
  }
  [[ $service_sslmode == require || $service_sslmode == verify-full ]] || {
    printf '%s\n' 'cloud role operations require sslmode=require or verify-full' >&2
    exit 2
  }
fi
export PGSERVICEFILE="$service_file"
exec env -u PGHOSTADDR -u PGHOST -u PGPORT -u PGDATABASE -u PGUSER \
  psql -X --no-psqlrc "service=$service" \
  -v ON_ERROR_STOP=1 \
  -v target_env="$environment" \
  -v database_name="$database" \
  -v schema_name="$schema" \
  -v app_role="greeniteso_${environment}_app" \
  -v migrator_role="greeniteso_${environment}_migrator" \
  -f "$script_dir/../sql/neon_roles_verify.sql"
