#!/usr/bin/env bash
set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  apt-get update >/dev/null
  apt-get install -y shellcheck >/dev/null
fi

shellcheck -S warning *.sh tests/*.sh

echo "Тест shellcheck пройдено"
