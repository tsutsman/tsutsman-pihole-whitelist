#!/usr/bin/env bash
# Скрипт генерує файл whitelist.txt на основі всіх списків у каталозі categories/
# Коментарі й порожні рядки ігноруються.
set -euo pipefail

OUTFILE="whitelist.txt"

echo "# Автоматично згенеровано скриптом generate_whitelist.sh" > "$OUTFILE"

# Збираємо рядки з усіх файлів та усуваємо дублікати
cat categories/*.txt \
  | grep -v '^\s*#' \
  | sed '/^\s*$/d' \
  | sort -u >> "$OUTFILE"

echo "Файл $OUTFILE згенеровано на основі categories/"
