#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat <<'LIST' > "$tmpdir/list.txt"
good.com
bad.invalid
LIST

cat <<'HOST' > "$tmpdir/host"
#!/usr/bin/env bash
if [[ "$1" == "good.com" ]]; then
  echo "good.com has address 1.2.3.4"
  exit 0
else
  echo "Host $1 not found" >&2
  exit 1
fi
HOST
chmod +x "$tmpdir/host"

export PATH="$tmpdir:$PATH"

if ./check_duplicates.sh "$tmpdir/list.txt" >/dev/null 2>&1; then
  echo "Скрипт мав завершитись помилкою" >&2
  exit 1
fi

echo "Тест check_duplicates.sh пройдено"
