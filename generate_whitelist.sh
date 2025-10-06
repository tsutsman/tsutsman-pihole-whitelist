#!/usr/bin/env bash
# Скрипт генерує файл whitelist.txt на основі списків у каталозі categories/
# Якщо передано аргументи, обробляються лише зазначені файли чи каталоги
# Коментарі (окремі та після доменів) й порожні рядки ігноруються
set -euo pipefail

OUTFILE=${OUTFILE:-"whitelist.txt"}
SOURCES_COMBINED=${SOURCES_COMBINED:-"sources/generated/all_sources.txt"}
INCLUDE_EXTERNAL_SOURCES=${INCLUDE_EXTERNAL_SOURCES:-1}

print_usage() {
  cat <<'EOF'
Використання: ./generate_whitelist.sh [опції] [файли_or_каталоги]

  -o, --output Файл для збереження результату (за замовчуванням whitelist.txt або значення змінної OUTFILE)
  -h, --help   Показати цю довідку

Можна передавати як окремі файли, так і каталоги з файлами .txt. Якщо аргументи відсутні,
буде використано всі файли у каталозі categories/.
EOF
}

args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--output)
      if [ "${2:-}" = "" ]; then
        echo "Потрібно вказати значення для $1" >&2
        exit 1
      fi
      OUTFILE="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      args+=("$@")
      break
      ;;
    -*)
      echo "Невідомий параметр: $1" >&2
      exit 1
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [ "${#args[@]}" -gt 0 ]; then
  set -- "${args[@]}"
else
  set --
fi

if [ -z "$OUTFILE" ]; then
  echo "Ім'я вихідного файлу не може бути порожнім" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTFILE")"

echo "# Автоматично згенеровано скриптом generate_whitelist.sh" > "$OUTFILE"

shopt -s nullglob
files=()

if [ "$#" -eq 0 ]; then
  files=(categories/*.txt)
else
  for item in "$@"; do
    if [ -d "$item" ]; then
      tmp=("$item"/*.txt)
      files+=("${tmp[@]}")
    elif [ -f "$item" ]; then
      files+=("$item")
    else
      echo "Пропущено неіснуючий шлях: $item" >&2
    fi
  done
fi

if [ "$INCLUDE_EXTERNAL_SOURCES" = "1" ] && [ -f "$SOURCES_COMBINED" ]; then
  files+=("$SOURCES_COMBINED")
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "Не знайдено жодного вхідного файлу" >&2
  exit 1
fi

# Збираємо рядки, обрізаємо коментарі та усуваємо дублікати
cat "${files[@]}" \
  | sed 's/#.*//' \
  | sed 's/^[ \t]*//;s/[ \t]*$//' \
  | sed '/^$/d' \
  | LC_ALL=C sort -u >> "$OUTFILE"

echo "Файл $OUTFILE згенеровано"
