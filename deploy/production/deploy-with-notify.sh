#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
APP_URL="${FORTIS_APP_URL:-http://85.208.87.187/}"
DEPLOY_ENV="${FORTIS_DEPLOY_ENV:-dev-vm}"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "${value}"
}

notification_payload() {
  local status="$1"
  local ref="$2"
  local exit_code="${3:-}"
  local line="${4:-}"
  local payload

  payload="{\"status\":\"$(json_escape "${status}")\",\"environment\":\"$(json_escape "${DEPLOY_ENV}")\",\"ref\":\"$(json_escape "${ref}")\",\"url\":\"$(json_escape "${APP_URL}")\""
  if [[ -n "${exit_code}" ]]; then
    payload+=",\"exitCode\":\"$(json_escape "${exit_code}")\""
  fi
  if [[ -n "${line}" ]]; then
    payload+=",\"line\":\"$(json_escape "${line}")\""
  fi
  payload+="}"
  printf '%s' "${payload}"
}

send_notification() {
  local status="$1"
  local ref="$2"
  local exit_code="${3:-}"
  local line="${4:-}"

  if [[ -z "${DEPLOY_NOTIFY_WEBHOOK_URL:-}" ]]; then
    printf 'Deploy notification skipped: DEPLOY_NOTIFY_WEBHOOK_URL is empty.\n' >&2
    return 0
  fi

  if ! curl --connect-timeout 5 --max-time 15 -fsS -X POST "${DEPLOY_NOTIFY_WEBHOOK_URL}" \
    -H "content-type: application/json" \
    --data "$(notification_payload "${status}" "${ref}" "${exit_code}" "${line}")" >/dev/null; then
    printf 'Deploy notification failed, continuing deploy.\n' >&2
  fi
}

compose() {
  docker compose --env-file "${ENV_FILE}" "$@"
}

build_ref() {
  git -C "${SCRIPT_DIR}/../.." rev-parse --short HEAD 2>/dev/null || date -u '+%Y%m%dT%H%M%SZ'
}

load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    printf 'Missing env file: %s\n' "${ENV_FILE}" >&2
    exit 1
  fi

  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
}

verify_services() {
  compose ps
  compose exec -T backend wget -qO- http://127.0.0.1:8090/_/readiness >/dev/null
  compose exec -T frontend wget -qO- http://127.0.0.1:3000/ >/dev/null
}

main() {
  load_env

  local ref started_at
  ref="$(build_ref)"
  started_at="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

  on_error() {
    local exit_code="$1"
    local line="$2"
    send_notification "failed" "${ref}" "${exit_code}" "${line}"
    exit "${exit_code}"
  }

  trap 'on_error $? $LINENO' ERR

  send_notification "started" "${ref}" "" ""
  printf 'Fortis deploy started: %s ref=%s started=%s url=%s\n' "${DEPLOY_ENV}" "${ref}" "${started_at}" "${APP_URL}"
  compose up -d --build
  verify_services

  trap - ERR
  send_notification "succeeded" "${ref}" "" ""
}

if [[ "${FORTIS_DEPLOY_NOTIFY_TEST_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

main "$@"
