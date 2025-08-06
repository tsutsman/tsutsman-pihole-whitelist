#!/usr/bin/env bash
set -euo pipefail

rm -f whitelist.txt
./generate_whitelist.sh >/dev/null

grep -q '^google.com' whitelist.txt

if [ "$(tail -n +2 whitelist.txt | sort -u)" != "$(tail -n +2 whitelist.txt)" ]; then
  echo "whitelist.txt не відсортовано або містить дублікати" >&2
  exit 1
fi

echo "Інтеграційний тест успішно пройдено"
