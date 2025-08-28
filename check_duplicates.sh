#!/usr/bin/env bash
# Скрипт перевіряє списки на дублікати та доступність доменів.
# Використання: ./check_duplicates.sh [файли або каталоги]
set -euo pipefail

if command -v host >/dev/null 2>&1; then
  lookup_cmd=(host -W1)
elif command -v nslookup >/dev/null 2>&1; then
  lookup_cmd=(nslookup -timeout=1)
else
  echo "Не знайдено утиліт host або nslookup" >&2
  exit 1
fi

check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Файл $file не знайдено" >&2
    return 1
  fi

  local dup
  local invalid=0
  # Видаляємо коментарі, щоб дублікати шукалися лише за доменами
  dup=$(grep -v '^\s*#' "$file" \
    | sed '/^\s*$/d' \
    | cut -d '#' -f1 \
    | awk '{print $1}' \
    | sort \
    | uniq -d)
  if [ -n "$dup" ]; then
    echo "Знайдені дублікати у $file:" >&2
    echo "$dup"
    return 1
  else
    echo "Дублікати не виявлені у $file"
  fi

  while read -r host; do
    if ! "${lookup_cmd[@]}" "$host" 2>&1 |
      grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}|([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}'; then
      echo "Недоступний домен: $host" >&2
      invalid=1
    fi
  done < <(grep -v '^\s*#' "$file" | sed '/^\s*$/d' | awk '{print $1}' | sed 's/^\*\.//')

  if (( invalid )); then
    return 1
  fi
}

if [ "$#" -eq 0 ]; then
  set -- whitelist.txt categories/*.txt
fi

status=0
for target in "$@"; do
  if [ -d "$target" ]; then
    for f in "$target"/*.txt; do
      check_file "$f" || status=1
    done
  else
    check_file "$target" || status=1
  fi
done

exit $status
