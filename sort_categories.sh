#!/usr/bin/env bash
# Сортує домени у файлах каталогу categories за абеткою.
# Використання: ./sort_categories.sh [каталог]
set -euo pipefail

dir=${1:-categories}
shopt -s nullglob

for file in "$dir"/*.txt; do
  [ "$(basename "$file")" = "deprecated.txt" ] && continue

  mapfile -t lines < "$file"
  header=()
  body=()
  in_header=1

  for line in "${lines[@]}"; do
    clean_line=${line//$'\r'/}
    if (( in_header )); then
      if [[ "$clean_line" =~ ^[[:space:]]*$ || "${clean_line:0:1}" == "#" ]]; then
        header+=("$clean_line")
        continue
      fi
      in_header=0
    fi
    body+=("$clean_line")
  done

  tmp=$(mktemp)
  {
    for line in "${header[@]}"; do
      printf '%s\n' "$line"
    done
    if (( ${#body[@]} )); then
      printf '%s\n' "${body[@]}" | LC_ALL=C sort -u
    fi
  } > "$tmp"

  mv "$tmp" "$file"
done

echo "Категорії у $dir впорядковано"
