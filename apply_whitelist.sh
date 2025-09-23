#!/usr/bin/env bash
# Скрипт додає домени з whitelist.txt до білого списку Pi-hole.
# Коментарі й порожні рядки ігноруються.
# Використання: ./apply_whitelist.sh [шлях_до_файла]
set -euo pipefail

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

# Визначення основної команди для додавання доменів залежно від версії Pi-hole
PIHOLE_VER=$(pihole -v -p 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo 5)
if [ "$PIHOLE_VER" -ge 6 ] && command -v pihole-FTL >/dev/null 2>&1; then
  add_cmd=(pihole-FTL whitelist add)
else
  add_cmd=(pihole -w)
fi

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi
  domain="${line%%#*}"
  domain="$(trim "$domain")"
  if [[ -z "$domain" ]]; then
    continue
  fi
  "${add_cmd[@]}" "$domain"
done < "$FILE"

echo "Доменів з $FILE додано до білого списку"
