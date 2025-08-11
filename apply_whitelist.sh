#!/usr/bin/env bash
# Скрипт додає домени з whitelist.txt до білого списку Pi-hole.
# Коментарі й порожні рядки ігноруються.
# Використання: ./apply_whitelist.sh [шлях_до_файла]
set -euo pipefail

FILE="${1:-whitelist.txt}"

if [ ! -f "$FILE" ]; then
  echo "Файл $FILE не знайдено" >&2
  exit 1
fi

if ! command -v pihole >/dev/null 2>&1; then
  echo "Команду pihole не знайдено" >&2
  exit 1
fi

grep -v '^\s*#' "$FILE" | sed '/^\s*$/d' | while read -r domain; do
  pihole -w "$domain"
done

echo "Доменів з $FILE додано до білого списку"
