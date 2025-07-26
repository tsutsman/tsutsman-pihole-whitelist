#!/usr/bin/env bash
# Скрипт перевіряє списки на дублікати та доступність доменів.
# Використання: ./check_duplicates.sh [файли або каталоги]
set -euo pipefail

check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Файл $file не знайдено" >&2
    return 1
  fi

  local dup
  dup=$(grep -v '^\s*#' "$file" | sed '/^\s*$/d' | sort | uniq -d)
  if [ -n "$dup" ]; then
    echo "Знайдені дублікати у $file:" >&2
    echo "$dup"
    return 1
  else
    echo "Дублікати не виявлені у $file"
  fi

  grep -v '^\s*#' "$file" | sed '/^\s*$/d' | awk '{print $1}' | sed 's/^\*\.//' | while read -r host; do
    if ! ping -c1 -W1 "$host" >/dev/null 2>&1; then
      echo "Недоступний домен: $host" >&2
    fi
  done
}

if [ "$#" -eq 0 ]; then
  set -- whitelist.txt categories/*.txt
fi

for target in "$@"; do
  if [ -d "$target" ]; then
    for f in "$target"/*.txt; do
      check_file "$f"
    done
  else
    check_file "$target"
  fi
done
