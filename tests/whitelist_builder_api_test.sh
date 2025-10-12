#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl не знайдено" >&2
  exit 1
fi

port=$(python3 - <<'PY'
import random
print(random.randint(40000, 50000))
PY
)

tmpdir=$(mktemp -d)
server_log="$tmpdir/server.log"
server_pid=""

cleanup() {
  if [[ -n "${server_pid:-}" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=""
  fi
  rm -rf "$tmpdir"
}

trap 'cleanup' EXIT

python3 whitelist_builder_api.py \
  --host 127.0.0.1 \
  --port "$port" \
  --data-dir "$tmpdir/output" \
  --log-file "$tmpdir/api.log" \
  >"$server_log" 2>&1 &
server_pid=$!

for attempt in $(seq 1 50); do
  if curl -fs "http://127.0.0.1:$port/health" >/dev/null; then
    break
  fi
  sleep 0.2
done

if ! curl -fs "http://127.0.0.1:$port/health" >/dev/null; then
  echo "API не відповідає" >&2
  if [[ -f "$server_log" ]]; then
    cat "$server_log" >&2
  fi
  exit 1
fi

categories_json=$(curl -fs "http://127.0.0.1:$port/api/categories")
CATEGORIES_PAYLOAD="$categories_json" python3 <<'PY'
import json, os
payload = json.loads(os.environ["CATEGORIES_PAYLOAD"])
if payload.get("status") != "ok":
    raise SystemExit("Некоректна відповідь /api/categories")
if not payload.get("categories"):
    raise SystemExit("Перелік категорій порожній")
PY

response=$(curl -fs -X POST "http://127.0.0.1:$port/api/build" \
  -H 'Content-Type: application/json' \
  -d '{"categories":["base.txt"],"include_external":false}')

RESPONSE_PAYLOAD="$response" python3 <<'PY'
import json, os
payload = json.loads(os.environ["RESPONSE_PAYLOAD"])
if payload.get("status") != "ok":
    raise SystemExit("Очікував статус ok")
if payload.get("domain_count", 0) <= 0:
    raise SystemExit("Нульова кількість доменів")
url = payload.get("download_url")
if not url or not url.startswith("/downloads/"):
    raise SystemExit("Некоректний download_url")
PY

file_name=$(RESPONSE_PAYLOAD="$response" python3 <<'PY'
import json, os
payload = json.loads(os.environ["RESPONSE_PAYLOAD"])
print(payload["download_url"].split("/")[-1])
PY
)
file_path="$tmpdir/output/$file_name"

if [[ ! -s "$file_path" ]]; then
  echo "Згенерований файл не знайдено" >&2
  exit 1
fi

if curl -fs "http://127.0.0.1:$port/api/build" -H 'Content-Type: application/json' -d '{}' >/dev/null; then
  echo "Порожній запит мав завершитися помилкою" >&2
  exit 1
fi

kill "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true
server_pid=""

echo "Тест whitelist_builder_api пройдено"
