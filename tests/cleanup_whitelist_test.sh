#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir "$tmpdir/categories"
cat <<'LIST' > "$tmpdir/categories/test.txt"
nonexistent.invalid
example.com
LIST

STATE_FILE="$tmpdir/state.txt" \
CATEGORIES_DIR="$tmpdir/categories" \
THRESHOLD=2 \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
./cleanup_whitelist.sh >/dev/null || true

# Після першого запуску домен не має бути в deprecated
if [[ -f "$tmpdir/categories/deprecated.txt" ]] && grep -q 'nonexistent.invalid' "$tmpdir/categories/deprecated.txt"; then
  echo "Домен потрапив до deprecated завчасно" >&2
  exit 1
fi

STATE_FILE="$tmpdir/state.txt" \
CATEGORIES_DIR="$tmpdir/categories" \
THRESHOLD=2 \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
./cleanup_whitelist.sh >/dev/null || true

grep -q 'nonexistent.invalid' "$tmpdir/categories/deprecated.txt"
! grep -q 'nonexistent.invalid' "$tmpdir/categories/test.txt"

grep -q 'example.com' "$tmpdir/categories/test.txt"
! grep -q 'example.com' "$tmpdir/categories/deprecated.txt"

echo "Тест cleanup_whitelist.sh пройдено"
