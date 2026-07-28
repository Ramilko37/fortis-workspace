#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/write-deploy-info.sh"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

output_file="$(mktemp)"
trap 'rm -f "${output_file}"' EXIT

"${SCRIPT_PATH}" "${output_file}"

grep -q '^DEPLOY_REF=' "${output_file}" || fail "expected parent ref"
grep -q '^DEPLOY_COMMIT_SUBJECT=' "${output_file}" || fail "expected parent commit subject"
grep -q '^DEPLOY_BRANCH=' "${output_file}" || fail "expected parent branch"
grep -q '^DEPLOY_FRONTEND_REF=' "${output_file}" || fail "expected frontend ref"
grep -q '^DEPLOY_FRONTEND_COMMIT_SUBJECT=' "${output_file}" || fail "expected frontend commit subject"
grep -q '^DEPLOY_BACKEND_REF=' "${output_file}" || fail "expected backend ref"
grep -q '^DEPLOY_BACKEND_COMMIT_SUBJECT=' "${output_file}" || fail "expected backend commit subject"
grep -q '^DEPLOY_GENERATED_AT=' "${output_file}" || fail "expected generated timestamp"

set -a
# shellcheck source=/dev/null
source "${output_file}"
set +a

[[ -n "${DEPLOY_REF}" ]] || fail "expected sourced parent ref"
[[ -n "${DEPLOY_COMMIT_SUBJECT}" ]] || fail "expected sourced parent subject"
[[ -n "${DEPLOY_FRONTEND_REF}" ]] || fail "expected sourced frontend ref"
[[ -n "${DEPLOY_BACKEND_REF}" ]] || fail "expected sourced backend ref"

printf 'ok - deploy info metadata contract\n'
