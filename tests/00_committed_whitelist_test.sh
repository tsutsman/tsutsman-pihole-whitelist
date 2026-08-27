#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [[ ! -f whitelist-exact.txt ]]; then
  echo "whitelist-exact.txt відсутній" >&2
  exit 1
fi

cp whitelist.txt "$tmpdir/whitelist.txt"
cp whitelist-exact.txt "$tmpdir/whitelist-exact.txt"

./generate_whitelist.sh >/dev/null
./generate_whitelist.sh --exact-only -o whitelist-exact.txt >/dev/null

if ! diff -u "$tmpdir/whitelist.txt" whitelist.txt; then
  echo "whitelist.txt не відповідає результату generate_whitelist.sh" >&2
  exit 1
fi

if ! diff -u "$tmpdir/whitelist-exact.txt" whitelist-exact.txt; then
  echo "whitelist-exact.txt не відповідає generate_whitelist.sh --exact-only" >&2
  exit 1
fi

echo "Комітнуті whitelist-артефакти синхронізовані з генератором"
