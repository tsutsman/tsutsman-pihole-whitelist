#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir "$tmpdir/categories"
cat <<'LIST' > "$tmpdir/categories/test.txt"
nonexistent.invalid # тимчасова проблема
example.com # стабільний домен
LIST

touch "$tmpdir/categories/empty.txt"

cat <<'HOST' > "$tmpdir/host"
#!/usr/bin/env bash
domain="${@: -1}"
if [[ "$domain" == "nonexistent.invalid" ]]; then
  exit 1
fi
exit 0
HOST
chmod +x "$tmpdir/host"

export PATH="$tmpdir:$PATH"

STATE_FILE="$tmpdir/state.txt" \
CATEGORIES_DIR="$tmpdir/categories" \
THRESHOLD=2 \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
LOG_FILE="$tmpdir/log.txt" \
PARALLEL=1 \
./cleanup_whitelist.sh >/dev/null

# Перевіряємо, що коментар збережено після першої невдалої перевірки
grep -Fxq 'nonexistent.invalid # тимчасова проблема' "$tmpdir/categories/test.txt"

# Фіксуємо, що стан містить інформацію про категорію
grep -Fxq 'nonexistent.invalid 1 test.txt' "$tmpdir/state.txt"

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
PARALLEL=1 \
./cleanup_whitelist.sh >/dev/null

grep -q 'nonexistent.invalid' "$tmpdir/categories/deprecated.txt"
! grep -q 'nonexistent.invalid # тимчасова проблема' "$tmpdir/categories/test.txt"

grep -Fxq 'nonexistent.invalid # category:test.txt' "$tmpdir/categories/deprecated.txt"
! grep -q 'nonexistent.invalid' "$tmpdir/state.txt"

grep -Fxq 'example.com # стабільний домен' "$tmpdir/categories/test.txt"
if [[ -f "$tmpdir/categories/deprecated.txt" ]] && grep -q '^example.com$' "$tmpdir/categories/deprecated.txt"; then
  echo "Стабільний домен example.com не повинен потрапляти до deprecated" >&2
  exit 1
fi

grep -q 'категорія: test.txt' "$tmpdir/log.txt"

before_parallel=$(cat "$tmpdir/categories/test.txt")

STATE_FILE="$tmpdir/state.txt" \
CATEGORIES_DIR="$tmpdir/categories" \
THRESHOLD=2 \
DEPRECATED_FILE="$tmpdir/categories/deprecated.txt" \
LOG_FILE="$tmpdir/log.txt" \
PARALLEL=2 \
./cleanup_whitelist.sh >/dev/null

if [[ "$before_parallel" != "$(cat "$tmpdir/categories/test.txt")" ]]; then
  echo "Паралельний режим не повинен змінювати стабільні записи" >&2
  exit 1
fi

if [[ -s "$tmpdir/categories/empty.txt" ]]; then
  echo "Порожня категорія не повинна заповнюватися автоматично" >&2
  exit 1
fi

echo "Тест cleanup_whitelist.sh пройдено"
