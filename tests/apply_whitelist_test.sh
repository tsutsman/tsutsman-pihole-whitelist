#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

export PIHOLE_CALLS_LOG="$tmpdir/calls.log"

cat <<'MOCK' > "$tmpdir/pihole"
#!/usr/bin/env bash
echo "$@" >> "$PIHOLE_CALLS_LOG"
MOCK
chmod +x "$tmpdir/pihole"

export PATH="$tmpdir:$PATH"

cat <<'LIST' > "$tmpdir/whitelist.txt"
# коментар
example.com

test.org
LIST

./apply_whitelist.sh "$tmpdir/whitelist.txt" >/dev/null

grep -Fxq -- "-w example.com" "$PIHOLE_CALLS_LOG"
grep -Fxq -- "-w test.org" "$PIHOLE_CALLS_LOG"

echo "Тест apply_whitelist.sh пройдено"
