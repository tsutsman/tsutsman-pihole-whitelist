#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "# коментар" > "$tmpdir/whitelist.txt"
echo "example.com" >> "$tmpdir/whitelist.txt"
echo "test.org" >> "$tmpdir/whitelist.txt"

# Функція створення мок-команд
create_mock() {
  local version=$1
  cat <<MOCK > "$tmpdir/pihole"
#!/usr/bin/env bash
if [[ "\$#" -ge 2 && "\$1" == "-v" && "\$2" == "-p" ]]; then
  echo "v$version.0.0"
else
  echo "\$@" >> "\$PIHOLE_CALLS_LOG"
fi
MOCK
  chmod +x "$tmpdir/pihole"
  if [[ $version -ge 6 ]]; then
    cat <<FTL > "$tmpdir/pihole-FTL"
#!/usr/bin/env bash
echo "\$@" >> "\$PIHOLE_CALLS_LOG"
FTL
    chmod +x "$tmpdir/pihole-FTL"
  fi
}

export PATH="$tmpdir:$PATH"
export PIHOLE_CALLS_LOG="$tmpdir/calls.log"

# Перевірка для v5
create_mock 5
./apply_whitelist.sh "$tmpdir/whitelist.txt" >/dev/null
grep -Fxq -- "-w example.com" "$PIHOLE_CALLS_LOG"
grep -Fxq -- "-w test.org" "$PIHOLE_CALLS_LOG"

# Перевірка для v6
> "$PIHOLE_CALLS_LOG"
create_mock 6
./apply_whitelist.sh "$tmpdir/whitelist.txt" >/dev/null
grep -Fxq -- "whitelist add example.com" "$PIHOLE_CALLS_LOG"
grep -Fxq -- "whitelist add test.org" "$PIHOLE_CALLS_LOG"

echo "Тест apply_whitelist.sh пройдено"
