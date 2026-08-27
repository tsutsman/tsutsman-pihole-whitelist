#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat <<'LIST' > "$tmpdir/list.txt"
good.com
bad.invalid
*.wild.invalid
LIST

HOST_LOG="$tmpdir/host_calls.log"
BARRIER_DIR="$tmpdir/barrier"
export HOST_LOG BARRIER_DIR

cat <<'HOST' > "$tmpdir/host"
#!/usr/bin/env bash
echo "$@" >> "$HOST_LOG"
domain="${@: -1}"
case "$domain" in
  good.com)
    echo "good.com has address 1.2.3.4"
    exit 0
    ;;
  parallel1.example|parallel2.example)
    mkdir -p "$BARRIER_DIR"
    touch "$BARRIER_DIR/$domain"
    for _ in $(seq 1 20); do
      if [[ -f "$BARRIER_DIR/parallel1.example" && -f "$BARRIER_DIR/parallel2.example" ]]; then
        echo "$domain has address 1.2.3.4"
        exit 0
      fi
      sleep 0.05
    done
    echo "Host $domain timed out waiting for concurrent lookup" >&2
    exit 1
    ;;
  *)
    echo "Host $domain not found" >&2
    exit 1
    ;;
esac
HOST
chmod +x "$tmpdir/host"

export PATH="$tmpdir:$PATH"

: > "$HOST_LOG"

if ./check_duplicates.sh "$tmpdir/list.txt" >/dev/null 2>&1; then
  echo "Скрипт мав завершитись помилкою" >&2
  exit 1
fi

if ! grep -q 'good.com' "$HOST_LOG"; then
  echo "DNS перевірка не викликала host" >&2
  exit 1
fi

if grep -q 'wild.invalid' "$HOST_LOG"; then
  echo "Wildcard base domain не повинен DNS-resolve'итись" >&2
  exit 1
fi

: > "$HOST_LOG"

if ! SKIP_DNS_CHECK=1 ./check_duplicates.sh "$tmpdir/list.txt" >/dev/null 2>&1; then
  echo "Скрипт мав ігнорувати перевірку DNS" >&2
  exit 1
fi

if [[ -s "$HOST_LOG" ]]; then
  echo "При SKIP_DNS_CHECK=1 host не повинен викликатись" >&2
  exit 1
fi

if ! SKIP_DNS_CHECK=yes ./check_duplicates.sh "$tmpdir/list.txt" >/dev/null 2>&1; then
  echo "Скрипт має приймати значення yes у SKIP_DNS_CHECK" >&2
  exit 1
fi

cat <<'PARALLEL' > "$tmpdir/parallel.txt"
parallel1.example
parallel2.example
PARALLEL
rm -rf "$BARRIER_DIR"
mkdir -p "$BARRIER_DIR"

if ! DNS_PARALLELISM=2 ./check_duplicates.sh "$tmpdir/parallel.txt" >/dev/null 2>&1; then
  echo "DNS перевірки мають виконуватись паралельно при DNS_PARALLELISM=2" >&2
  exit 1
fi

mkdir -p "$tmpdir/categories"
echo 'bad.invalid # category:test.txt' > "$tmpdir/categories/deprecated.txt"
echo 'test.txt|bad.invalid' > "$tmpdir/categories/comment_allowlist.txt"
: > "$HOST_LOG"

if ! ./check_duplicates.sh "$tmpdir/categories" >/dev/null 2>&1; then
  echo "Службові файли категорій не повинні спричиняти помилку перевірки" >&2
  exit 1
fi

if [[ -s "$HOST_LOG" ]]; then
  echo "DNS перевірка не повинна запускатись для службових файлів" >&2
  exit 1
fi

empty_file="$tmpdir/empty.txt"
: > "$empty_file"

if ! SKIP_DNS_CHECK=1 ./check_duplicates.sh "$empty_file" >/dev/null 2>&1; then
  echo "Порожній файл не повинен спричиняти помилку" >&2
  exit 1
fi

echo "Тест check_duplicates.sh пройдено"
