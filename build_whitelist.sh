#!/usr/bin/env bash
# Скрипт-прототип для побудови whitelist-файлу на основі вибраних категорій
# та додаткових шляхів. Використовує наявний generate_whitelist.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_SCRIPT="$SCRIPT_DIR/generate_whitelist.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply_whitelist.sh"

usage() {
  cat <<'USAGE'
Використання: build_whitelist.sh [опції]
  --categories "a.txt,b.txt"   Перелік файлів категорій із каталогу categories/
  --extra-path PATH             Додатковий шлях (файл або каталог), можна повторювати
  --include-external {0|1}      Чи підключати зовнішні джерела (за замовчуванням 1)
  --sources-combined PATH       Альтернативний комбінований файл джерел
  --apply-directly {0|1}        Одразу застосувати whitelist через apply_whitelist.sh
  --output PATH                 Куди зберегти результат (за замовчуванням ./whitelist-<дата>.txt)
  --help                        Показати цю довідку
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

categories_list=()
extra_paths=()
include_external=1
sources_combined=""
apply_directly=0
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --categories)
      if [[ $# -lt 2 ]]; then
        echo "Не передано значення для --categories" >&2
        exit 1
      fi
      IFS=',' read -r -a parsed <<<"$2"
      for item in "${parsed[@]}"; do
        item_trimmed="$(trim "$item")"
        if [[ -n "$item_trimmed" ]]; then
          categories_list+=("$item_trimmed")
        fi
      done
      shift 2
      ;;
    --extra-path)
      if [[ $# -lt 2 ]]; then
        echo "Не передано значення для --extra-path" >&2
        exit 1
      fi
      extra_paths+=("$2")
      shift 2
      ;;
    --include-external)
      if [[ $# -lt 2 ]]; then
        echo "Не передано значення для --include-external" >&2
        exit 1
      fi
      if [[ "$2" != "0" && "$2" != "1" ]]; then
        echo "--include-external приймає лише 0 або 1" >&2
        exit 1
      fi
      include_external="$2"
      shift 2
      ;;
    --sources-combined)
      if [[ $# -lt 2 ]]; then
        echo "Не передано значення для --sources-combined" >&2
        exit 1
      fi
      sources_combined="$2"
      shift 2
      ;;
    --apply-directly)
      if [[ $# -lt 2 ]]; then
        echo "Не передано значення для --apply-directly" >&2
        exit 1
      fi
      if [[ "$2" != "0" && "$2" != "1" ]]; then
        echo "--apply-directly приймає лише 0 або 1" >&2
        exit 1
      fi
      apply_directly="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Не передано значення для --output" >&2
        exit 1
      fi
      output_path="$2"
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
      echo "Невідомий позиційний аргумент: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -x "$GENERATE_SCRIPT" ]]; then
  echo "Скрипт generate_whitelist.sh не знайдено або він не є виконуваним" >&2
  exit 1
fi

inputs=()
for category in "${categories_list[@]}"; do
  if [[ -f "$category" || -d "$category" ]]; then
    inputs+=("$category")
    continue
  fi
  candidate="$SCRIPT_DIR/categories/$category"
  if [[ -f "$candidate" || -d "$candidate" ]]; then
    inputs+=("$candidate")
  else
    echo "Категорію $category не знайдено" >&2
    exit 1
  fi
done

for path in "${extra_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Додатковий шлях $path не існує" >&2
    exit 1
  fi
  inputs+=("$path")
done

workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

if [[ -z "$output_path" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  output_path="$PWD/whitelist-$timestamp.txt"
fi

output_dir="$(dirname "$output_path")"
mkdir -p "$output_dir"
output_path="$(cd "$output_dir" && pwd)/$(basename "$output_path")"

env_vars=("INCLUDE_EXTERNAL_SOURCES=$include_external")
if [[ -n "$sources_combined" ]]; then
  env_vars+=("SOURCES_COMBINED=$sources_combined")
fi

(
  cd "$workdir"
  env "${env_vars[@]}" "$GENERATE_SCRIPT" "${inputs[@]}" >/dev/null
)

tmp_output="$workdir/whitelist.txt"
if [[ ! -f "$tmp_output" ]]; then
  echo "Не вдалося знайти згенерований whitelist" >&2
  exit 1
fi

mv "$tmp_output" "$output_path"
trap - EXIT
rm -rf "$workdir"

echo "Whitelist збережено до $output_path"

if [[ "$apply_directly" == "1" ]]; then
  if [[ ! -x "$APPLY_SCRIPT" ]]; then
    echo "Скрипт apply_whitelist.sh не знайдено або він не є виконуваним" >&2
    exit 1
  fi
  "$APPLY_SCRIPT" "$output_path"
fi

printf '%s\n' "$output_path"
