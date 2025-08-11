#!/usr/bin/env bash
# Скрипт генерує файл whitelist.txt на основі списків у каталозі categories/
# Якщо передано аргументи, обробляються лише зазначені файли чи каталоги
# Коментарі й порожні рядки ігноруються
set -euo pipefail

OUTFILE="whitelist.txt"

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

if [ "${#files[@]}" -eq 0 ]; then
  echo "Не знайдено жодного вхідного файлу" >&2
  exit 1
fi

# Збираємо рядки з обраних файлів та усуваємо дублікати
cat "${files[@]}" \
  | grep -v '^\s*#' \
  | sed '/^\s*$/d' \
  | sort -u >> "$OUTFILE"

echo "Файл $OUTFILE згенеровано"
