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

grep -q 'Категорій проаналізовано: 2' "$workdir/docs/report.md"
grep -q 'shared.example' "$workdir/docs/report.md"
grep -q '\.example' "$workdir/docs/report.md"
grep -q 'extra.net' "$workdir/docs/report.md"
grep -q 'only_in_whitelist_examples' "$workdir/docs/report.json"

echo "Тест analyze_domains.py пройдено"
