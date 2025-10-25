#!/usr/bin/env bash
set -euo pipefail

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/categories" "$workdir/docs"

cat <<'CAT1' > "$workdir/categories/alpha.txt"
# @description: Тестова категорія А
first.example
shared.example
shared.example # повтор
third.co.uk
CAT1

cat <<'CAT2' > "$workdir/categories/beta.txt"
# @description: Тестова категорія B
second.example
shared.example
fourth.io
fifth.dev
sixth.app
CAT2

cat <<'WL' > "$workdir/whitelist.txt"
first.example
shared.example
extra.net
WL

CATEGORIES_DIR="$workdir/categories" \
WHITELIST_FILE="$workdir/whitelist.txt" \
DOMAIN_ANALYSIS_OUTPUT="$workdir/docs/report.md" \
DOMAIN_ANALYSIS_JSON="$workdir/docs/report.json" \
"$(pwd)/analyze_domains.py"

[[ -s "$workdir/docs/report.md" ]] || { echo "Markdown-звіт не згенеровано" >&2; exit 1; }
[[ -s "$workdir/docs/report.json" ]] || { echo "JSON-звіт не згенеровано" >&2; exit 1; }

DOMAIN_ANALYSIS_CATEGORY_SORT="total" \
DOMAIN_ANALYSIS_CATEGORY_SORT_ORDER="desc" \
DOMAIN_ANALYSIS_OUTPUT="$workdir/docs/report_sorted.md" \
DOMAIN_ANALYSIS_JSON="$workdir/docs/report_sorted.json" \
CATEGORIES_DIR="$workdir/categories" \
WHITELIST_FILE="$workdir/whitelist.txt" \
"$(pwd)/analyze_domains.py"

[[ -s "$workdir/docs/report_sorted.md" ]] || { echo "Markdown-звіт зі сортуванням не згенеровано" >&2; exit 1; }

grep -q 'Категорій проаналізовано: 2' "$workdir/docs/report.md"
grep -q 'shared.example' "$workdir/docs/report.md"
grep -q '\.example' "$workdir/docs/report.md"
grep -q 'extra.net' "$workdir/docs/report.md"
grep -q 'only_in_whitelist_examples' "$workdir/docs/report.json"

beta_line=$(grep -n '| beta.txt |' "$workdir/docs/report_sorted.md" | cut -d: -f1)
alpha_line=$(grep -n '| alpha.txt |' "$workdir/docs/report_sorted.md" | cut -d: -f1)

if [[ -z "$beta_line" || -z "$alpha_line" ]]; then
  echo "Не знайдено рядки таблиці категорій у відсортованому звіті" >&2
  exit 1
fi

if (( beta_line >= alpha_line )); then
  echo "Сортування категорій за total не працює" >&2
  exit 1
fi

echo "Тест analyze_domains.py пройдено"
