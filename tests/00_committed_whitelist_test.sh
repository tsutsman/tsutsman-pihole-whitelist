#!/usr/bin/env bash
set -euo pipefail

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

cp whitelist.txt "$tmpfile"
./generate_whitelist.sh >/dev/null

if ! diff -u "$tmpfile" whitelist.txt; then
  echo "whitelist.txt не відповідає результату generate_whitelist.sh" >&2
  exit 1
fi

echo "Комітнутий whitelist.txt синхронізований з генератором"
