#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/categories" "$tmpdir/generated" "$tmpdir/docs"

cat <<'CAT' > "$tmpdir/categories/sample.txt"
# @description: Тестова категорія
# @author: QA
# @last_review: 2024-05-01

stable.example
unstable.example # тимчасова проблема
CAT

cat <<'STATE' > "$tmpdir/state.txt"
unstable.example 1 sample.txt
STATE

cat <<'DEPR' > "$tmpdir/categories/deprecated.txt"
old.example # category:sample.txt
DEPR

cat <<'SRC' > "$tmpdir/sources.txt"
Sample source|https://example.com/list.txt|
SRC

cat <<'SRCFILE' > "$tmpdir/generated/sample_source.txt"
stable.example
SRCFILE

cat <<'LOG' > "$tmpdir/cleanup.log"
2024-05-01 10:00:00 old.example -> вилучено після 3 невдалих перевірок (категорія: sample.txt)
LOG

CATEGORIES_DIR="$tmpdir/categories" \
SOURCES_CONFIG="$tmpdir/sources.txt" \
GENERATED_DIR="$tmpdir/generated" \
STATE_FILE="$tmpdir/state.txt" \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
REPORT_FILE="$tmpdir/docs/report.md" \
HTML_REPORT_FILE="$tmpdir/docs/dashboard.html" \
HISTORY_FILE="$tmpdir/docs/history.json" \
LOG_FILE="$tmpdir/cleanup.log" \
REMOVAL_HISTORY_LIMIT=10 \
"$(pwd)/generate_stats_report.sh"

grep -q 'Активних доменів у категоріях: 2' "$tmpdir/docs/report.md"
grep -q 'Sample source' "$tmpdir/docs/report.md"

if [[ ! -s "$tmpdir/docs/dashboard.html" ]]; then
  echo "HTML-звіт не створено" >&2
  exit 1
fi

grep -q 'Моніторинг білого списку Pi-hole' "$tmpdir/docs/dashboard.html"
grep -q 'Журнал видалень' "$tmpdir/docs/dashboard.html"

if [[ ! -s "$tmpdir/docs/history.json" ]]; then
  echo "Історію не збережено" >&2
  exit 1
fi

python3 - "$tmpdir/docs/history.json" <<'PY'
import json, sys
data = json.loads(open(sys.argv[1], encoding='utf-8').read())
if not data:
    raise SystemExit('Порожня історія')
required = {'timestamp', 'active_domains', 'problematic_domains', 'deprecated_domains'}
if not required.issubset(data[-1]):
    raise SystemExit('Бракує ключів в історії')
PY

echo "Тест generate_stats_report.sh пройдено"
