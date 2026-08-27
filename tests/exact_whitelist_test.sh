#!/usr/bin/env bash
set -euo pipefail

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

OUTFILE="$tmpfile" ./generate_whitelist.sh --exact-only categories/apple.txt >/dev/null

if grep -q '^\*\.' "$tmpfile"; then
  echo "--exact-only не повинен містити wildcard-записи" >&2
  exit 1
fi

if ! grep -q '^appleid.apple.com$' "$tmpfile"; then
  echo "--exact-only вилучив звичайний exact domain" >&2
  exit 1
fi

echo "Тест exact-only генерації пройдено"
