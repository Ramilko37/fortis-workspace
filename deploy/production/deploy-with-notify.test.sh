#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/deploy-with-notify.sh"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

curl_calls=()
curl_exit_code=0
curl() {
  curl_calls+=("$*")
  return "${curl_exit_code}"
}

export FORTIS_DEPLOY_NOTIFY_TEST_MODE=1
# shellcheck source=deploy/production/deploy-with-notify.sh
source "${SCRIPT_PATH}"

test_send_notification_posts_to_worker_webhook() {
  DEPLOY_NOTIFY_WEBHOOK_URL="https://worker.example/deploy/deploy-secret"
  DEPLOY_ENV="dev-vm"
  APP_URL="http://85.208.87.187/"
  DEPLOY_COMMIT_SUBJECT="feat: add build notifications"
  DEPLOY_BRANCH="codex/deploy-notifications"
  DEPLOY_FRONTEND_REF="front123"
  DEPLOY_FRONTEND_COMMIT_SUBJECT="feat: frontend polish"
  DEPLOY_BACKEND_REF="back123"
  DEPLOY_BACKEND_COMMIT_SUBJECT="fix: backend readiness"

  send_notification "succeeded" "abc1234" "" ""

  [[ "${#curl_calls[@]}" -eq 1 ]] || fail "expected one curl call"
  [[ "${curl_calls[0]}" == *"https://worker.example/deploy/deploy-secret"* ]] || fail "expected Worker webhook URL"
  [[ "${curl_calls[0]}" == *"--connect-timeout 5"* ]] || fail "expected Worker connect timeout"
  [[ "${curl_calls[0]}" == *"--max-time 15"* ]] || fail "expected Worker max timeout"
  [[ "${curl_calls[0]}" == *'"status":"succeeded"'* ]] || fail "expected status JSON"
  [[ "${curl_calls[0]}" == *'"environment":"dev-vm"'* ]] || fail "expected environment JSON"
  [[ "${curl_calls[0]}" == *'"ref":"abc1234"'* ]] || fail "expected ref JSON"
  [[ "${curl_calls[0]}" == *'"commitSubject":"feat: add build notifications"'* ]] || fail "expected commit subject JSON"
  [[ "${curl_calls[0]}" == *'"branch":"codex/deploy-notifications"'* ]] || fail "expected branch JSON"
  [[ "${curl_calls[0]}" == *'"frontendRef":"front123"'* ]] || fail "expected frontend ref JSON"
  [[ "${curl_calls[0]}" == *'"frontendCommitSubject":"feat: frontend polish"'* ]] || fail "expected frontend subject JSON"
  [[ "${curl_calls[0]}" == *'"backendRef":"back123"'* ]] || fail "expected backend ref JSON"
  [[ "${curl_calls[0]}" == *'"backendCommitSubject":"fix: backend readiness"'* ]] || fail "expected backend subject JSON"
}

test_send_notification_skips_when_webhook_missing() {
  curl_calls=()
  DEPLOY_NOTIFY_WEBHOOK_URL=""

  send_notification "started" "abc1234" "" ""

  [[ "${#curl_calls[@]}" -eq 0 ]] || fail "expected no curl call without webhook URL"
}

test_send_notification_does_not_fail_deploy_when_webhook_fails() {
  curl_calls=()
  curl_exit_code=28
  DEPLOY_NOTIFY_WEBHOOK_URL="https://worker.example/deploy/deploy-secret"

  send_notification "failed" "abc1234" "28" "64"

  [[ "${#curl_calls[@]}" -eq 1 ]] || fail "expected one curl attempt"
}

compose_calls=()
frontend_health_failures=0
compose() {
  compose_calls+=("$*")
  if [[ "$*" == exec\ -T\ frontend* && "${frontend_health_failures}" -gt 0 ]]; then
    frontend_health_failures=$((frontend_health_failures - 1))
    return 1
  fi
  return 0
}

sleep() {
  return 0
}

test_verify_services_waits_for_frontend_readiness() {
  compose_calls=()
  frontend_health_failures=1
  DEPLOY_HEALTHCHECK_ATTEMPTS=3
  DEPLOY_HEALTHCHECK_DELAY_SECONDS=0

  verify_services

  [[ "${frontend_health_failures}" -eq 0 ]] || fail "expected frontend retry to consume transient failure"
  [[ "${#compose_calls[@]}" -eq 4 ]] || fail "expected ps, backend, and two frontend healthcheck calls"
}

test_load_deploy_info_exports_generated_metadata() {
  local info_file
  info_file="$(mktemp)"
  cat >"${info_file}" <<'INFO'
DEPLOY_REF=parent123
DEPLOY_COMMIT_SUBJECT='feat: parent deploy metadata'
DEPLOY_BRANCH=main
DEPLOY_FRONTEND_REF=front456
DEPLOY_FRONTEND_COMMIT_SUBJECT='feat: frontend map'
DEPLOY_BACKEND_REF=back789
DEPLOY_BACKEND_COMMIT_SUBJECT='fix: backend health'
INFO

  DEPLOY_INFO_FILE="${info_file}"
  load_deploy_info

  [[ "${DEPLOY_REF}" == "parent123" ]] || fail "expected deploy ref from deploy info"
  [[ "${DEPLOY_COMMIT_SUBJECT}" == "feat: parent deploy metadata" ]] || fail "expected parent subject from deploy info"
  [[ "${DEPLOY_FRONTEND_COMMIT_SUBJECT}" == "feat: frontend map" ]] || fail "expected frontend subject from deploy info"
  [[ "${DEPLOY_BACKEND_COMMIT_SUBJECT}" == "fix: backend health" ]] || fail "expected backend subject from deploy info"

  rm -f "${info_file}"
}

test_send_notification_posts_to_worker_webhook
test_send_notification_skips_when_webhook_missing
test_send_notification_does_not_fail_deploy_when_webhook_fails
test_verify_services_waits_for_frontend_readiness
test_load_deploy_info_exports_generated_metadata
printf 'ok - deploy Worker notification contract\n'
