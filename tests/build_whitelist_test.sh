#!/usr/bin/env bash
set -euo pipefail

TMP_OUTPUT="$(mktemp)"
rm -f "$TMP_OUTPUT"

result="$(./build_whitelist.sh --categories "base.txt" --include-external 0 --output "$TMP_OUTPUT")"

last_line="${result##*$'\n'}"
if [[ "$last_line" != "$TMP_OUTPUT" ]]; then
  echo "Очікуваний шлях $TMP_OUTPUT у виводі, отримано $last_line" >&2
  exit 1
fi

if [[ ! -f "$TMP_OUTPUT" ]]; then
  echo "Файл $TMP_OUTPUT не створено" >&2
  exit 1
fi

grep -q '^# Автоматично згенеровано' "$TMP_OUTPUT"
grep -q '^google.com' "$TMP_OUTPUT"

# Перевірка додаткового шляху
TMP_DIR="$(mktemp -d)"
cat <<'DOMAINS' > "$TMP_DIR/custom.txt"
example.test
DOMAINS

second_output="$(mktemp)"
rm -f "$second_output"

./build_whitelist.sh --extra-path "$TMP_DIR/custom.txt" --include-external 0 --output "$second_output" >/dev/null

if ! grep -q '^example.test$' "$second_output"; then
  echo "Додатковий шлях не було враховано" >&2
  rm -rf "$TMP_DIR"
  exit 1
fi

rm -rf "$TMP_DIR"
rm -f "$TMP_OUTPUT" "$second_output"

echo "build_whitelist.sh пройшов базові перевірки"
