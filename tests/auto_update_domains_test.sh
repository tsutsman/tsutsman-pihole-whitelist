#!/usr/bin/env bash
set -euo pipefail

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/categories"

cat <<'CAT' > "$TMP_DIR/categories/base.txt"
example.com # базовий домен
CAT

cat <<'SRC' > "$TMP_DIR/source.txt"
# коментар
external.test
SRC

cat <<EOF2 > "$TMP_DIR/sources.txt"
local|file://$TMP_DIR/source.txt
EOF2

OUTPUT_FILE="$TMP_DIR/whitelist.txt"
LOG_FILE="$TMP_DIR/update.log"

./auto_update_domains.sh \
  --sources-config "$TMP_DIR/sources.txt" \
  --sources-out-dir "$TMP_DIR/sources" \
  --sources-combined "$TMP_DIR/sources/all_sources.txt" \
  --categories "$TMP_DIR/categories" \
  --output "$OUTPUT_FILE" \
  --include-external 1 \
  --skip-fetch 0 \
  --update-analysis 0 \
  --apply-directly 0 \
  --log-file "$LOG_FILE" >/dev/null

if [ ! -f "$OUTPUT_FILE" ]; then
  echo "Whitelist не створено" >&2
  exit 1
fi

if ! grep -qx 'example.com' "$OUTPUT_FILE"; then
  echo "example.com відсутній у whitelist" >&2
  exit 1
fi

if ! grep -qx 'external.test' "$OUTPUT_FILE"; then
  echo "external.test відсутній у whitelist" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "Лог-файл не створено" >&2
  exit 1
fi

echo "Тест auto_update_domains.sh пройдено"
