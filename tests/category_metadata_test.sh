#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
validate_script="$project_root/validate_category_metadata.sh"

if [[ ! -x "$validate_script" ]]; then
  echo "Скрипт validate_category_metadata.sh не знайдено" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir "$tmpdir/categories"
cat <<'CAT' > "$tmpdir/categories/sample.txt"
# @description: Тестова категорія
# @author: QA
# @last_review: 2024-05-01

domain.example
CAT

CATEGORIES_DIR="$tmpdir/categories" "$validate_script" >/dev/null

cat <<'BROKEN' > "$tmpdir/categories/broken.txt"
# @description: Неповний запис
# @author: QA

domain.invalid
BROKEN

if CATEGORIES_DIR="$tmpdir/categories" "$validate_script" >/dev/null 2>&1; then
  echo "Перевірка мала провалитись для неповного файлу" >&2
  exit 1
fi

echo "Тест метаданих категорій пройдено"
