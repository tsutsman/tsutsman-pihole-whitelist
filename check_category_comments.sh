#!/usr/bin/env bash
set -euo pipefail

CATEGORIES_DIR=${CATEGORIES_DIR:-categories}
ALLOWLIST_FILE=${ALLOWLIST_FILE:-$CATEGORIES_DIR/comment_allowlist.txt}
IGNORE_FILE=${IGNORE_FILE:-deprecated.txt}
ALLOWLIST_NAME="$(basename "$ALLOWLIST_FILE")"

trim() {
  local value="$1"
  value="${value%%$'\r'*}"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

if [[ ! -d "$CATEGORIES_DIR" ]]; then
  echo "Каталог категорій $CATEGORIES_DIR не знайдено" >&2
  exit 1
fi

declare -A allowlist=()
declare -A used_allowlist=()

if [[ -f "$ALLOWLIST_FILE" ]]; then
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ ${line:0:1} == '#' ]] && continue
    allowlist["$line"]=1
  done < "$ALLOWLIST_FILE"
fi

mapfile -t category_files < <(find "$CATEGORIES_DIR" -maxdepth 1 -type f -name '*.txt' ! -name "$IGNORE_FILE" ! -name "$ALLOWLIST_NAME" | LC_ALL=C sort)

if [[ ${#category_files[@]} -eq 0 ]]; then
  echo "У каталозі $CATEGORIES_DIR немає файлів категорій" >&2
  exit 1
fi

declare -a errors=()

for file in "${category_files[@]}"; do
  category_name="$(basename "$file")"
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    trimmed_line="$(trim "$raw_line")"
    [[ -z "$trimmed_line" ]] && continue
    [[ ${trimmed_line:0:1} == '#' ]] && continue
    domain="$(trim "${raw_line%%#*}")"
    [[ -z "$domain" ]] && continue
    entry="$category_name|$domain"
    if [[ "$raw_line" == *'#'* ]]; then
      if [[ -n "${allowlist[$entry]:-}" ]]; then
        continue
      fi
      continue
    fi
    if [[ -n "${allowlist[$entry]:-}" ]]; then
      used_allowlist["$entry"]=1
      continue
    fi
    errors+=("$category_name:$domain")
  done < "$file"

done

if (( ${#errors[@]} )); then
  echo "Знайдено домени без коментарів (відсутні в дозволеному списку):" >&2
  for item in "${errors[@]}"; do
    echo " - $item" >&2
  done
  exit 1
fi

if [[ -f "$ALLOWLIST_FILE" ]]; then
  declare -a stale=()
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ ${line:0:1} == '#' ]] && continue
    if [[ -z "${used_allowlist[$line]:-}" ]]; then
      stale+=("$line")
    fi
  done < "$ALLOWLIST_FILE"
  if (( ${#stale[@]} )); then
    echo "Попередження: у файлі дозволених записів є застарілі значення:" >&2
    for item in "${stale[@]}"; do
      echo " - $item" >&2
    done
    echo "Вилучіть зайві рядки з $ALLOWLIST_FILE або додайте коментарі у відповідні файли." >&2
    exit 1
  fi
fi

echo "Перевірка коментарів у категоріях успішна."
