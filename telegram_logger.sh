#!/usr/bin/env bash
set -euo pipefail

tg_log() {
  local message="${1:-}"
  if [[ -z "${message}" ]]; then
    return 0
  fi
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    return 0
  fi

  local api_url="${TELEGRAM_API_URL:-https://api.telegram.org}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS -X POST "${api_url}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=${message}" >/dev/null || true
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "${api_url}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      --post-data "chat_id=${TELEGRAM_CHAT_ID}&text=${message}" >/dev/null || true
  fi
}
