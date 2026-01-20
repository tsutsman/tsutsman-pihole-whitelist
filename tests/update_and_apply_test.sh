#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "example.com" > "$tmpdir/whitelist.txt"

cat <<MOCK > "$tmpdir/pihole"
#!/usr/bin/env bash
if [[ "\$1" == "-v" && "\$2" == "-p" ]]; then
  echo "v5.0.0"
else
  echo "\$@" >> "$tmpdir/calls.log"
fi
MOCK
chmod +x "$tmpdir/pihole"
export PATH="$tmpdir:$PATH"
export TELEGRAM_BOT_TOKEN="test-token"
export TELEGRAM_CHAT_ID="test-chat"
export TELEGRAM_API_URL="https://api.telegram.org"
export TELEGRAM_CALLS_LOG="$tmpdir/telegram_calls.log"

cat <<'MOCK' > "$tmpdir/curl"
#!/usr/bin/env bash
out=""
url=""
for arg in "$@"; do
  if [[ "$arg" == *"sendMessage"* ]]; then
    echo "$*" >> "$TELEGRAM_CALLS_LOG"
    exit 0
  fi
done

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -fsSL)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

if [[ -n "$out" && "$url" == file://* ]]; then
  cp "${url#file://}" "$out"
  exit 0
fi

exit 1
MOCK
chmod +x "$tmpdir/curl"

touch "$tmpdir/calls.log"
REPO_URL="file://$tmpdir/whitelist.txt" LOG_FILE="$tmpdir/update.log" ./update_and_apply.sh >/dev/null

grep -Fxq -- "-w example.com" "$tmpdir/calls.log"
grep -q 'Список оновлено та застосовано' "$tmpdir/update.log"
grep -q "sendMessage" "$tmpdir/telegram_calls.log"

echo "Тест update_and_apply.sh пройдено"
