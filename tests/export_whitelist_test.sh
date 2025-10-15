#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

export_script="$project_root/export_whitelist.sh"
if [[ ! -x "$export_script" ]]; then
  echo "Скрипт export_whitelist.sh не знайдено" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat <<'LIST' > "$tmpdir/sample.txt"
# Коментар
example.com
sub.domain.com # inline comment
example.com

LIST

ADGUARD_OUT="$tmpdir/adguard.txt"
PFB_OUT="$tmpdir/pfblocker.txt"

"$export_script" --source "$tmpdir/sample.txt" --format adguard-home --output "$ADGUARD_OUT" >/dev/null
"$export_script" --source "$tmpdir/sample.txt" --format pfblockerng --output "$PFB_OUT" >/dev/null

if [[ ! -s "$ADGUARD_OUT" ]]; then
  echo "AdGuard Home експорт порожній" >&2
  exit 1
fi

if [[ ! -s "$PFB_OUT" ]]; then
  echo "pfBlockerNG експорт порожній" >&2
  exit 1
fi

if ! diff -u <(printf '%s\n' '@@||example.com^' '@@||sub.domain.com^') <(cat "$ADGUARD_OUT") >/dev/null; then
  echo "AdGuard Home експорт має некоректний вміст" >&2
  cat "$ADGUARD_OUT" >&2
  exit 1
fi

if ! diff -u <(printf '%s\n' 'example.com' 'sub.domain.com') <(cat "$PFB_OUT") >/dev/null; then
  echo "pfBlockerNG експорт має некоректний вміст" >&2
  cat "$PFB_OUT" >&2
  exit 1
fi

echo "Тест export_whitelist.sh пройдено"
