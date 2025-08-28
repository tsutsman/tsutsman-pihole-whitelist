#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir "$tmpdir/cat"
cat <<'LIST' > "$tmpdir/cat/test.txt"
zzz.com
aaa.com
LIST

./sort_categories.sh "$tmpdir/cat" >/dev/null
diff <(cat "$tmpdir/cat/test.txt") <(printf "aaa.com\nzzz.com\n")

echo "Тест sort_categories.sh пройдено"
