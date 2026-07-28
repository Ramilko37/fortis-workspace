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

  send_notification "succeeded" "abc1234" "" ""

  [[ "${#curl_calls[@]}" -eq 1 ]] || fail "expected one curl call"
  [[ "${curl_calls[0]}" == *"https://worker.example/deploy/deploy-secret"* ]] || fail "expected Worker webhook URL"
  [[ "${curl_calls[0]}" == *"--connect-timeout 5"* ]] || fail "expected Worker connect timeout"
  [[ "${curl_calls[0]}" == *"--max-time 15"* ]] || fail "expected Worker max timeout"
  [[ "${curl_calls[0]}" == *'"status":"succeeded"'* ]] || fail "expected status JSON"
  [[ "${curl_calls[0]}" == *'"environment":"dev-vm"'* ]] || fail "expected environment JSON"
  [[ "${curl_calls[0]}" == *'"ref":"abc1234"'* ]] || fail "expected ref JSON"
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

test_send_notification_posts_to_worker_webhook
test_send_notification_skips_when_webhook_missing
test_send_notification_does_not_fail_deploy_when_webhook_fails
printf 'ok - deploy Worker notification contract\n'
