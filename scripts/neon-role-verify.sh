#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: neon-role-verify.sh --environment dev|staging|production \
  --service PGSERVICE --service-file FILE --expected-host HOST --expected-port PORT \
  [--database DATABASE] [--schema SCHEMA]

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
while (($#)); do
  case "$1" in
    --environment) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; environment=$2; shift 2 ;;
    --service) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; service=$2; shift 2 ;;
    --service-file) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; service_file=$2; shift 2 ;;
    --expected-host) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; expected_host=$2; shift 2 ;;
    --expected-port) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; expected_port=$2; shift 2 ;;
    --database) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; database=$2; shift 2 ;;
    --schema) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; schema=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $environment =~ ^(dev|staging|production)$ ]] || { printf '%s\n' 'environment must be dev, staging, or production' >&2; exit 2; }
[[ -n $service && $service =~ ^[A-Za-z0-9_.-]+$ ]] || { printf '%s\n' 'a pg_service name is required' >&2; exit 2; }
[[ -n $service_file && -r $service_file ]] || { printf '%s\n' 'a readable pg_service file is required' >&2; exit 2; }
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
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export PGSERVICEFILE="$service_file"
exec psql -X --no-psqlrc "service=$service" \
  -v ON_ERROR_STOP=1 \
  -v target_env="$environment" \
  -v database_name="$database" \
  -v schema_name="$schema" \
  -v app_role="greeniteso_${environment}_app" \
  -v migrator_role="greeniteso_${environment}_migrator" \
  -f "$script_dir/../sql/neon_roles_verify.sql"
