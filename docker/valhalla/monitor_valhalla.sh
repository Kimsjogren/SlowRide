#!/usr/bin/env bash

set -euo pipefail

STATUS_URL="${STATUS_URL:-http://127.0.0.1:8002/status}"
CONTAINER_NAME="${CONTAINER_NAME:-slowride-valhalla}"
STATE_FILE="${STATE_FILE:-/tmp/valhalla-monitor.state}"
HOST_LABEL="${HOST_LABEL:-$(hostname)}"

send_ntfy() {
  if [[ -z "${NTFY_TOPIC:-}" ]]; then
    return 0
  fi

  curl -fsS -X POST "https://ntfy.sh/${NTFY_TOPIC}" \
    -H "Title: ${1}" \
    -H "Priority: ${2}" \
    -d "${3}" >/dev/null
}

send_telegram() {
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    return 0
  fi

  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${1}" >/dev/null
}

send_alert() {
  local title="$1"
  local priority="$2"
  local body="$3"

  send_ntfy "${title}" "${priority}" "${body}" || true
  send_telegram "${title}"$'\n'"${body}" || true
}

last_state="unknown"
if [[ -f "${STATE_FILE}" ]]; then
  last_state="$(cat "${STATE_FILE}")"
fi

if curl -fsS --max-time 10 "${STATUS_URL}" >/dev/null; then
  if [[ "${last_state}" != "healthy" ]]; then
    send_alert \
      "Valhalla recovered on ${HOST_LABEL}" \
      "default" \
      "Health check is green again: ${STATUS_URL}"
  fi
  echo "healthy" > "${STATE_FILE}"
  exit 0
fi

docker_state="$(docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "${CONTAINER_NAME}" 2>/dev/null || echo missing)"

if [[ "${last_state}" != "failing" ]]; then
  send_alert \
    "Valhalla down on ${HOST_LABEL}" \
    "high" \
    "Health check failed for ${STATUS_URL}. Container state: ${docker_state}"
fi

echo "failing" > "${STATE_FILE}"
exit 1
