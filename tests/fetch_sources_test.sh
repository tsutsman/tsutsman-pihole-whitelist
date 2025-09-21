#!/usr/bin/env bash
set -euo pipefail

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cat <<'SRC1' > "$TMP_DIR/source1.txt"
# коментар
example.com    # основний домен
0.0.0.0 local.test
@@||Wildcard.com^
address=/internal.service/127.0.0.1
SRC1

cat <<'SRC2' > "$TMP_DIR/source2.txt"
; початок
https://sub.domain.example/path
another.com extra
server=/service.local/1.1.1.1
SRC2

cat <<EOF2 > "$TMP_DIR/sources.txt"
first|file://$TMP_DIR/source1.txt
second|file://$TMP_DIR/source2.txt
EOF2

OUT_DIR="$TMP_DIR/out" COMBINED_FILE="$TMP_DIR/out/combined.txt" ./fetch_sources.sh "$TMP_DIR/sources.txt" >/dev/null

if [ ! -f "$TMP_DIR/out/first.txt" ] || [ ! -f "$TMP_DIR/out/second.txt" ]; then
  echo "Не створені файли для джерел" >&2
  exit 1
fi

if ! grep -qx 'example.com' "$TMP_DIR/out/first.txt"; then
  echo "example.com відсутній у обробленому файлі" >&2
  exit 1
fi

if grep -q '^0\.0\.0\.0' "$TMP_DIR/out/first.txt"; then
  echo "IP-адреса не була вилучена" >&2
  exit 1
fi

if ! grep -qx 'wildcard.com' "$TMP_DIR/out/first.txt"; then
  echo "wildcard.com відсутній після очищення" >&2
  exit 1
fi

if ! grep -qx 'internal.service' "$TMP_DIR/out/first.txt"; then
  echo "internal.service не оброблено з address=/" >&2
  exit 1
fi

if ! grep -qx 'sub.domain.example' "$TMP_DIR/out/second.txt"; then
  echo "sub.domain.example не знайдений" >&2
  exit 1
fi

if ! grep -qx 'another.com' "$TMP_DIR/out/second.txt"; then
  echo "another.com відсутній" >&2
  exit 1
fi

if ! grep -qx 'service.local' "$TMP_DIR/out/second.txt"; then
  echo "service.local не оброблено з server=/" >&2
  exit 1
fi

if ! grep -qx 'internal.service' "$TMP_DIR/out/combined.txt"; then
  echo "Зведений файл не містить доменів" >&2
  exit 1
fi

if [ "$(sort "$TMP_DIR/out/combined.txt" | uniq | wc -l)" -ne "$(wc -l < "$TMP_DIR/out/combined.txt")" ]; then
  echo "Зведений файл містить дублікати" >&2
  exit 1
fi

echo "Тест fetch_sources.sh пройдено"
