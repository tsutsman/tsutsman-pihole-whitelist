#!/usr/bin/env bash
# Скрипт перевіряє домени з каталогу categories та переносить недоступні
# протягом N останніх перевірок до файлу deprecated.txt.
# Використовує файл стану з кількістю поспіль невдалих перевірок.

set -euo pipefail

# Обрізання пробілів на початку та в кінці рядка
trim() {
  local var="$1"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# Виділення домену без коментаря
extract_domain() {
  local line="$1"
  line="${line%%#*}"
  trim "$line"
}

# Вибір доступної утиліти для DNS-запитів
if command -v host >/dev/null 2>&1; then
  lookup_cmd=(host -W1)
elif command -v nslookup >/dev/null 2>&1; then
  lookup_cmd=(nslookup -timeout=1)
else
  echo "Не знайдено утиліт host або nslookup" >&2
  exit 1
fi

# Шлях до каталогу з категоріями (за замовчуванням 'categories')
CATEGORIES_DIR=${CATEGORIES_DIR:-categories}
# Файл для збереження кількості невдалих перевірок
STATE_FILE=${STATE_FILE:-cleanup_state.txt}
# Поріг видалення (кількість поспіль невдалих перевірок)
THRESHOLD=${THRESHOLD:-3}
# Файл для доменів, що видалено
DEPRECATED_FILE=${DEPRECATED_FILE:-$CATEGORIES_DIR/deprecated.txt}
# Файл журналу причин видалення
LOG_FILE=${LOG_FILE:-cleanup.log}
# Кількість паралельних перевірок
PARALLEL=${PARALLEL:-4}

# Завантаження наявного стану
declare -A FAILS
if [[ -f "$STATE_FILE" ]]; then
  while read -r domain count; do
    FAILS[$domain]=$count
  done < "$STATE_FILE"
fi

# Очищення файлу стану для подальшого запису
: > "$STATE_FILE"

# Обробка всіх файлів у каталозі категорій, окрім deprecated.txt
while IFS= read -r -d '' file; do
  tmp=$(mktemp)
  mapfile -t lines < "$file"
  domains=()
  for line in "${lines[@]}"; do
    clean_line=${line//$'\r'/}
    domain="$(extract_domain "$clean_line")"
    if [[ -n "$domain" ]]; then
      domains+=("$domain")
    fi
  done

  tmp_checks=$(mktemp)
  pids=()
  for domain in "${domains[@]}"; do
    (
      if "${lookup_cmd[@]}" "$domain" >/dev/null 2>&1; then
        echo "$domain ok" >> "$tmp_checks"
      else
        echo "$domain fail" >> "$tmp_checks"
      fi
    ) &
    pids+=($!)
    if (( ${#pids[@]} >= PARALLEL )); then
      wait "${pids[@]}"
      pids=()
    fi
  done
  wait "${pids[@]}"

  declare -A RES
  while read -r d status; do
    RES[$d]=$status
  done < "$tmp_checks"
  rm -f "$tmp_checks"

  for line in "${lines[@]}"; do
    clean_line=${line//$'\r'/}
    if [[ "$clean_line" =~ ^[[:space:]]*$ || "${clean_line:0:1}" == "#" ]]; then
      echo "$clean_line" >> "$tmp"
      continue
    fi
    domain="$(extract_domain "$clean_line")"
    if [[ -z "$domain" ]]; then
      echo "$clean_line" >> "$tmp"
      continue
    fi
    if [[ ${RES[$domain]} == "ok" ]]; then
      unset 'FAILS[$domain]'
      echo "$clean_line" >> "$tmp"
    else
      count=${FAILS[$domain]:-0}
      count=$((count+1))
      if (( count >= THRESHOLD )); then
        grep -Fxq "$domain" "$DEPRECATED_FILE" 2>/dev/null || echo "$domain" >> "$DEPRECATED_FILE"
        echo "$(date '+%F %T') $domain -> вилучено після $THRESHOLD невдалих перевірок" >> "$LOG_FILE"
        unset 'FAILS[$domain]'
      else
        FAILS[$domain]=$count
        echo "$clean_line" >> "$tmp"
      fi
    fi
  done
  mv "$tmp" "$file"
  rm -f "$tmp"

  : > "$STATE_FILE.tmp"
  for d in "${!FAILS[@]}"; do
    echo "$d ${FAILS[$d]}" >> "$STATE_FILE.tmp"
  done
  mv "$STATE_FILE.tmp" "$STATE_FILE"

done < <(find "$CATEGORIES_DIR" -type f -name '*.txt' ! -name 'deprecated.txt' -print0)
