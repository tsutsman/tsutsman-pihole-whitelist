#!/usr/bin/env bash
# Сортує домени у файлах каталогу categories за абеткою.
# Використання: ./sort_categories.sh [каталог]
set -euo pipefail

dir=${1:-categories}
for file in "$dir"/*.txt; do
  [ "$(basename "$file")" = "deprecated.txt" ] && continue
  sort -u "$file" -o "$file"
done

echo "Категорії у $dir впорядковано"
