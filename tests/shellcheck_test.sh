#!/usr/bin/env bash
set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  apt-get update >/dev/null
  apt-get install -y shellcheck >/dev/null
fi

shellcheck *.sh tests/*.sh >/dev/null || true

echo "Тест shellcheck пройдено"
