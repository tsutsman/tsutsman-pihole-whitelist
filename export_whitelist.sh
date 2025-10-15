#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="whitelist.txt"
FORMAT=""
OUTPUT_FILE=""
DEFAULT_DIR="exports"

usage() {
  cat <<'USAGE'
Використання: ./export_whitelist.sh --format <формат> [--source <файл>] [--output <файл>]
Доступні формати:
  - adguard-home
  - pfblockerng

Параметри:
  --format    Формат експорту (обов'язковий).
  --source    Вхідний файл зі списком доменів (за замовчуванням whitelist.txt).
  --output    Файл призначення. Якщо не вказано, результат буде збережено у каталозі exports.
  --help      Показати це повідомлення.
USAGE
}

trim() {
  local value="$1"
  value="${value%%$'\r'*}"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      [[ $# -lt 2 ]] && { echo "Прапорець --format потребує значення" >&2; exit 1; }
      FORMAT="$2"
      shift 2
      ;;
    --source)
      [[ $# -lt 2 ]] && { echo "Прапорець --source потребує значення" >&2; exit 1; }
      SOURCE_FILE="$2"
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && { echo "Прапорець --output потребує значення" >&2; exit 1; }
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Невідомий аргумент: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FORMAT" ]]; then
  echo "Необхідно вказати формат експорту через --format" >&2
  usage >&2
  exit 1
fi

case "$FORMAT" in
  adguard-home|pfblockerng)
    ;;
  *)
    echo "Непідтримуваний формат: $FORMAT" >&2
    exit 1
    ;;
esac

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Вхідний файл $SOURCE_FILE не знайдено" >&2
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  mkdir -p "$DEFAULT_DIR"
  base_name=$(basename "$SOURCE_FILE")
  base_name=${base_name%.*}
  OUTPUT_FILE="$DEFAULT_DIR/${base_name}-${FORMAT}.txt"
else
  mkdir -p "$(dirname "$OUTPUT_FILE")"
fi

tmp_output=$(mktemp)
trap 'rm -f "$tmp_output"' EXIT

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  trimmed="$(trim "$raw_line")"
  [[ -z "$trimmed" ]] && continue
  [[ ${trimmed:0:1} == '#' ]] && continue
  domain="$(trim "${raw_line%%#*}")"
  domain="$(trim "$domain")"
  [[ -z "$domain" ]] && continue
  case "$FORMAT" in
    adguard-home)
      printf '@@||%s^\n' "$domain" >> "$tmp_output"
      ;;
    pfblockerng)
      printf '%s\n' "$domain" >> "$tmp_output"
      ;;
  esac
done < "$SOURCE_FILE"

if [[ ! -s "$tmp_output" ]]; then
  echo "У вхідному файлі немає доменів для експорту" >&2
  : > "$OUTPUT_FILE"
  exit 0
fi

LC_ALL=C sort -u "$tmp_output" > "$OUTPUT_FILE"

echo "Експорт збережено у $OUTPUT_FILE"
