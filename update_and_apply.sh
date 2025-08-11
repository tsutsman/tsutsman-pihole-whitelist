#!/usr/bin/env bash
# Скрипт завантажує whitelist.txt з основної гілки репозиторію та застосовує його.
# Використання: додайте до cron, наприклад, щотижня у неділю о 03:00:
# 0 3 * * 0 /path/to/update_and_apply.sh >> /var/log/update_whitelist.log 2>&1
set -euo pipefail

# URL до файлу whitelist.txt у гілці main
REPO_URL=${REPO_URL:-"https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt"}
# Файл журналу
LOG_FILE=${LOG_FILE:-"update.log"}

TMP_FILE=$(mktemp)

delete_tmp() {
  rm -f "$TMP_FILE"
}
trap delete_tmp EXIT

# Завантаження whitelist.txt
if command -v curl >/dev/null 2>&1; then
  if ! curl -fsSL "$REPO_URL" -o "$TMP_FILE"; then
    echo "Не вдалося завантажити whitelist.txt" >&2
    exit 1
  fi
elif command -v wget >/dev/null 2>&1; then
  if ! wget -qO "$TMP_FILE" "$REPO_URL"; then
    echo "Не вдалося завантажити whitelist.txt" >&2
    exit 1
  fi
else
  echo "Не знайдено curl або wget" >&2
  exit 1
fi

if [ ! -s "$TMP_FILE" ]; then
  echo "Завантажений файл порожній" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! "$SCRIPT_DIR/apply_whitelist.sh" "$TMP_FILE"; then
  echo "Помилка під час застосування whitelist" >&2
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') Список оновлено та застосовано" | tee -a "$LOG_FILE"
