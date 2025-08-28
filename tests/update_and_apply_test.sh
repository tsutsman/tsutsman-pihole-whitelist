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

touch "$tmpdir/calls.log"
REPO_URL="file://$tmpdir/whitelist.txt" LOG_FILE="$tmpdir/update.log" ./update_and_apply.sh >/dev/null

grep -Fxq -- "-w example.com" "$tmpdir/calls.log"
grep -q 'Список оновлено та застосовано' "$tmpdir/update.log"

echo "Тест update_and_apply.sh пройдено"
