#!/usr/bin/env bash
# Скрипт додає домени з whitelist.txt до білого списку Pi-hole.
# Коментарі й порожні рядки ігноруються; записи *.domain обробляються як wildcard allowlist.
# Використання: ./apply_whitelist.sh [шлях_до_файла]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -f "$SCRIPT_DIR/telegram_logger.sh" ]; then
  # shellcheck source=telegram_logger.sh
  source "$SCRIPT_DIR/telegram_logger.sh"
fi

FILE="${1:-whitelist.txt}"

# Обрізання пробілів по краях рядка
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

if [ ! -f "$FILE" ]; then
  echo "Файл $FILE не знайдено" >&2
  exit 1
fi

if ! command -v pihole >/dev/null 2>&1; then
  echo "Команду pihole не знайдено" >&2
  exit 1
fi

tg_log "$(date '+%Y-%m-%d %H:%M:%S') Початок застосування whitelist: $FILE"

# У Pi-hole v6 для allowlist використовуються `pihole allow` та `pihole --allow-wild`.
# Для v5 зберігаємо сумісність через `pihole -w` і legacy regex-whitelist.
PIHOLE_VER=$(pihole -v -p 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo 5)

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  domain="${line%%#*}"
  domain="$(trim "$domain")"
  if [[ -z "$domain" ]]; then
    continue
  fi

  if [[ "$domain" == \*.* ]]; then
    base_domain="${domain#*.}"
    if [ "$PIHOLE_VER" -ge 6 ]; then
      pihole --allow-wild "$base_domain"
    else
      escaped_domain="${base_domain//./\\\\.}"
      pihole --white-regex "(^|\\.)${escaped_domain}$"
    fi
  elif [ "$PIHOLE_VER" -ge 6 ]; then
    pihole allow "$domain"
  else
    pihole -w "$domain"
  fi
done < "$FILE"

echo "Доменів з $FILE додано до білого списку"
tg_log "$(date '+%Y-%m-%d %H:%M:%S') Застосування whitelist завершено: $FILE"
