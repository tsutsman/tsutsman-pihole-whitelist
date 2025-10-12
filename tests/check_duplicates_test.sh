#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat <<'LIST' > "$tmpdir/list.txt"
good.com
bad.invalid
LIST

HOST_LOG="$tmpdir/host_calls.log"
export HOST_LOG

cat <<'HOST' > "$tmpdir/host"
#!/usr/bin/env bash
echo "$@" >> "$HOST_LOG"
domain="${@: -1}"
if [[ "$domain" == "good.com" ]]; then
  echo "good.com has address 1.2.3.4"
  exit 0
else
  echo "Host $domain not found" >&2
  exit 1
fi
HOST
chmod +x "$tmpdir/host"

export PATH="$tmpdir:$PATH"

> "$HOST_LOG"

if ./check_duplicates.sh "$tmpdir/list.txt" >/dev/null 2>&1; then
  echo "Скрипт мав завершитись помилкою" >&2
  exit 1
fi

if ! grep -q 'good.com' "$HOST_LOG"; then
  echo "DNS перевірка не викликала host" >&2
  exit 1
fi

> "$HOST_LOG"

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

echo "Тест check_duplicates.sh пройдено"
