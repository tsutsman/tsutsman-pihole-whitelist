#!/usr/bin/env bash
# Скрипт автоматично актуалізує домени з локальних категорій і зовнішніх джерел.
# Кроки: завантаження джерел, генерація whitelist, опційний аналіз і застосування.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FETCH_SCRIPT="$SCRIPT_DIR/fetch_sources.sh"
GENERATE_SCRIPT="$SCRIPT_DIR/generate_whitelist.sh"
ANALYZE_SCRIPT="$SCRIPT_DIR/analyze_domains.py"
APPLY_SCRIPT="$SCRIPT_DIR/apply_whitelist.sh"

usage() {
  cat <<'USAGE'
Використання: auto_update_domains.sh [опції]
  --sources-config PATH      Файл джерел для fetch_sources.sh (за замовчуванням sources/default_sources.txt)
  --sources-out-dir PATH     Каталог для збереження джерел (за замовчуванням sources/generated)
  --sources-combined PATH    Комбінований файл джерел (за замовчуванням <sources-out-dir>/all_sources.txt)
  --categories PATH          Файл або каталог категорій, можна повторювати (за замовчуванням categories/)
  --output PATH              Куди зберегти whitelist (за замовчуванням whitelist.txt)
  --include-external {0|1}   Чи підключати зовнішні джерела (за замовчуванням 1)
  --skip-fetch {0|1}         Чи пропустити завантаження джерел (за замовчуванням 0)
  --update-analysis {0|1}    Чи оновлювати аналітичні звіти (за замовчуванням 0)
  --apply-directly {0|1}     Чи одразу застосувати whitelist (за замовчуванням 0)
  --log-file PATH            Шлях до лог-файлу (за замовчуванням update_domains.log)
  --help                     Показати довідку
USAGE
}

log_msg() {
  local message="$1"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" | tee -a "$LOG_FILE"
}

sources_config="$SCRIPT_DIR/sources/default_sources.txt"
sources_out_dir="$SCRIPT_DIR/sources/generated"
sources_combined=""
output_path="$SCRIPT_DIR/whitelist.txt"
include_external=1
skip_fetch=0
update_analysis=0
apply_directly=0
log_file="$SCRIPT_DIR/update_domains.log"
inputs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sources-config)
      sources_config="$2"
      shift 2
      ;;
    --sources-out-dir)
      sources_out_dir="$2"
      shift 2
      ;;
    --sources-combined)
      sources_combined="$2"
      shift 2
      ;;
    --categories)
      inputs+=("$2")
      shift 2
      ;;
    --output)
      output_path="$2"
      shift 2
      ;;
    --include-external)
      include_external="$2"
      shift 2
      ;;
    --skip-fetch)
      skip_fetch="$2"
      shift 2
      ;;
    --update-analysis)
      update_analysis="$2"
      shift 2
      ;;
    --apply-directly)
      apply_directly="$2"
      shift 2
      ;;
    --log-file)
      log_file="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    --*)
      echo "Невідома опція: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Невідомий аргумент: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$sources_combined" ]]; then
  sources_combined="$sources_out_dir/all_sources.txt"
fi

if [[ "$include_external" != "0" && "$include_external" != "1" ]]; then
  echo "--include-external приймає лише 0 або 1" >&2
  exit 1
fi

if [[ "$skip_fetch" != "0" && "$skip_fetch" != "1" ]]; then
  echo "--skip-fetch приймає лише 0 або 1" >&2
  exit 1
fi

if [[ "$update_analysis" != "0" && "$update_analysis" != "1" ]]; then
  echo "--update-analysis приймає лише 0 або 1" >&2
  exit 1
fi

if [[ "$apply_directly" != "0" && "$apply_directly" != "1" ]]; then
  echo "--apply-directly приймає лише 0 або 1" >&2
  exit 1
fi

LOG_FILE="$log_file"

if [[ ! -x "$GENERATE_SCRIPT" ]]; then
  echo "Скрипт generate_whitelist.sh не знайдено або він не є виконуваним" >&2
  exit 1
fi

if [[ "$skip_fetch" == "0" && "$include_external" == "1" ]]; then
  if [[ ! -x "$FETCH_SCRIPT" ]]; then
    echo "Скрипт fetch_sources.sh не знайдено або він не є виконуваним" >&2
    exit 1
  fi
fi

if [[ "${#inputs[@]}" -eq 0 ]]; then
  inputs=("$SCRIPT_DIR/categories")
fi

for path in "${inputs[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Шлях $path не існує" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "$output_path")"
mkdir -p "$(dirname "$LOG_FILE")"

log_msg "Початок автоматичної актуалізації доменів"

if [[ "$skip_fetch" == "0" && "$include_external" == "1" ]]; then
  log_msg "Оновлюємо зовнішні джерела доменів"
  OUT_DIR="$sources_out_dir" \
  COMBINED_FILE="$sources_combined" \
  "$FETCH_SCRIPT" "$sources_config" >/dev/null
  log_msg "Зовнішні джерела оновлено"
else
  log_msg "Зовнішні джерела пропущено"
fi

workdir=$(mktemp -d)
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

new_whitelist="$workdir/whitelist.txt"

log_msg "Генеруємо whitelist"
INCLUDE_EXTERNAL_SOURCES="$include_external" \
SOURCES_COMBINED="$sources_combined" \
"$GENERATE_SCRIPT" -o "$new_whitelist" "${inputs[@]}" >/dev/null

if [[ ! -s "$new_whitelist" ]]; then
  echo "Згенерований whitelist порожній" >&2
  exit 1
fi

if [[ -f "$output_path" ]] && cmp -s "$new_whitelist" "$output_path"; then
  log_msg "Змін у whitelist не виявлено"
else
  mv "$new_whitelist" "$output_path"
  log_msg "Whitelist оновлено: $output_path"
fi

if [[ "$update_analysis" == "1" ]]; then
  if [[ ! -x "$ANALYZE_SCRIPT" ]]; then
    echo "Скрипт analyze_domains.py не знайдено або він не є виконуваним" >&2
    exit 1
  fi
  log_msg "Оновлюємо аналітичні звіти"
  "$ANALYZE_SCRIPT" >/dev/null
  log_msg "Аналітичні звіти оновлено"
fi

if [[ "$apply_directly" == "1" ]]; then
  if [[ ! -x "$APPLY_SCRIPT" ]]; then
    echo "Скрипт apply_whitelist.sh не знайдено або він не є виконуваним" >&2
    exit 1
  fi
  log_msg "Застосовуємо whitelist до Pi-hole"
  "$APPLY_SCRIPT" "$output_path" >/dev/null
  log_msg "Whitelist застосовано"
fi

log_msg "Актуалізацію доменів завершено"

printf '%s\n' "$output_path"
