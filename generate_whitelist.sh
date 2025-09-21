#!/usr/bin/env bash
# Скрипт генерує файл whitelist.txt на основі списків у каталозі categories/
# Якщо передано аргументи, обробляються лише зазначені файли чи каталоги
# Коментарі (окремі та після доменів) й порожні рядки ігноруються
set -euo pipefail

OUTFILE="whitelist.txt"
SOURCES_COMBINED=${SOURCES_COMBINED:-"sources/generated/all_sources.txt"}
INCLUDE_EXTERNAL_SOURCES=${INCLUDE_EXTERNAL_SOURCES:-1}

echo "# Автоматично згенеровано скриптом generate_whitelist.sh" > "$OUTFILE"

shopt -s nullglob
files=()

if [ "$#" -eq 0 ]; then
  files=(categories/*.txt)
else
  for item in "$@"; do
    if [ -d "$item" ]; then
      tmp=("$item"/*.txt)
      files+=("${tmp[@]}")
    elif [ -f "$item" ]; then
      files+=("$item")
    else
      echo "Пропущено неіснуючий шлях: $item" >&2
    fi
  done
fi

if [ "$INCLUDE_EXTERNAL_SOURCES" = "1" ] && [ -f "$SOURCES_COMBINED" ]; then
  files+=("$SOURCES_COMBINED")
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "Не знайдено жодного вхідного файлу" >&2
  exit 1
fi

# Збираємо рядки, обрізаємо коментарі та усуваємо дублікати
cat "${files[@]}" \
  | sed 's/#.*//' \
  | sed 's/^[ \t]*//;s/[ \t]*$//' \
  | sed '/^$/d' \
  | LC_ALL=C sort -u >> "$OUTFILE"

echo "Файл $OUTFILE згенеровано"
