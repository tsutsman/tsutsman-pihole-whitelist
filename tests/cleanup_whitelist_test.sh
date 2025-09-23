#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir "$tmpdir/categories"
cat <<'LIST' > "$tmpdir/categories/test.txt"
nonexistent.invalid # тимчасова проблема
example.com # стабільний домен
LIST

STATE_FILE="$tmpdir/state.txt" \
CATEGORIES_DIR="$tmpdir/categories" \
THRESHOLD=2 \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
LOG_FILE="$tmpdir/log.txt" \
./cleanup_whitelist.sh >/dev/null || true

# Перевіряємо, що коментар збережено після першої невдалої перевірки
grep -Fxq 'nonexistent.invalid # тимчасова проблема' "$tmpdir/categories/test.txt"

# Після першого запуску домен не має бути в deprecated
if [[ -f "$tmpdir/categories/deprecated.txt" ]] && grep -q 'nonexistent.invalid' "$tmpdir/categories/deprecated.txt"; then
  echo "Домен потрапив до deprecated завчасно" >&2
  exit 1
fi

STATE_FILE="$tmpdir/state.txt" \
CATEGORIES_DIR="$tmpdir/categories" \
THRESHOLD=2 \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
LOG_FILE="$tmpdir/log.txt" \
./cleanup_whitelist.sh >/dev/null || true

grep -q 'nonexistent.invalid' "$tmpdir/categories/deprecated.txt"
! grep -q 'nonexistent.invalid # тимчасова проблема' "$tmpdir/categories/test.txt"

grep -q 'example.com # стабільний домен' "$tmpdir/categories/test.txt"
! grep -q 'example.com' "$tmpdir/categories/deprecated.txt"

grep -q 'nonexistent.invalid' "$tmpdir/log.txt"

echo "Тест cleanup_whitelist.sh пройдено"
