#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: neon-branches-plan.sh --project-id PROJECT --parent BRANCH

Read the branch inventory and print reviewed, secret-free commands for the
three-environment plan. This script never creates, deletes, resets, or changes
a Neon branch.
EOF
}

project_id=''
parent_branch=''
while (($#)); do
  case "$1" in
    --project-id) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; project_id=$2; shift 2 ;;
    --parent) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; parent_branch=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $project_id =~ ^[a-z0-9-]+$ ]] || { printf '%s\n' 'project id is required and must be a Neon id' >&2; exit 2; }
[[ $parent_branch =~ ^[A-Za-z0-9._/-]+$ ]] || { printf '%s\n' 'parent branch is required' >&2; exit 2; }
command -v neon >/dev/null 2>&1 || { printf '%s\n' 'neon CLI is required' >&2; exit 127; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required to avoid proposing duplicate branch creation' >&2; exit 127; }

inventory_file=$(mktemp)
trap 'rm -f "$inventory_file"' EXIT
umask 077

# Branch listing contains metadata only. Keep it mode 600 so a future CLI
# cannot put a connection URI in terminal logs.
neon branches list --project-id "$project_id" --output json >"$inventory_file"

printf '%s\n' 'Observed branch inventory (metadata only):'
jq -r 'if type == "array" then . else (.branches // []) end
  | .[] | "  \(.name) [\(.id)] parent=\(.parent_id // "root") default=\(.default // false)"' "$inventory_file"

printf '\n%s\n' 'Reviewed creation commands for missing targets (run only after human review):'
for target in staging dev; do
  if jq -e --arg target "$target" '(if type == "array" then . else (.branches // []) end)
      | any(.[]; .name == $target)' "$inventory_file" >/dev/null; then
    printf '  %s already exists; verify its parent is %q\n' "$target" "$parent_branch"
  else
    printf 'neon branches create --project-id %q --parent %q --name %q --cu 0.25-1 --no-secrets\n' "$project_id" "$parent_branch" "$target"
  fi
done
printf '\n%s\n' 'After each operation, re-run this inventory and verify branch id/name mapping.'
printf '%s\n' 'Free plan may reject --suspend-timeout; rely on the project global default (currently 300s) when omitted.'
printf '%s\n' 'Do not run connection-string or env-pull commands in this plan step.'
