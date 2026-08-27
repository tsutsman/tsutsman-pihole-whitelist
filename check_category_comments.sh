#!/usr/bin/env bash
set -euo pipefail

CATEGORIES_DIR=${CATEGORIES_DIR:-categories}
ALLOWLIST_FILE=${ALLOWLIST_FILE:-$CATEGORIES_DIR/comment_allowlist.txt}
IGNORE_FILE=${IGNORE_FILE:-deprecated.txt}
COMMENT_BASE_REF=${COMMENT_BASE_REF:-}
ALLOWLIST_NAME="$(basename "$ALLOWLIST_FILE")"

trim() {
  local value="$1"
  value="${value%%$'\r'*}"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

is_category_data_file() {
  local path="$1"
  local name
  name="$(basename "$path")"
  [[ "$path" == *.txt ]] || return 1
  [[ "$name" != "$IGNORE_FILE" ]] || return 1
  [[ "$name" != "$ALLOWLIST_NAME" ]] || return 1
  return 0
}

if [[ ! -d "$CATEGORIES_DIR" ]]; then
  echo "Каталог категорій $CATEGORIES_DIR не знайдено" >&2
  exit 1
fi

declare -A allowlist=()
declare -A used_allowlist=()
declare -A legacy_uncommented=()

if [[ -f "$ALLOWLIST_FILE" ]]; then
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ ${line:0:1} == '#' ]] && continue
    allowlist["$line"]=1
  done < "$ALLOWLIST_FILE"
fi

# У CI можна передати базовий commit/ref. Тоді старі записи без inline-коментарів
# не блокують збірку, але будь-який новий uncommented domain завершує перевірку помилкою.
if [[ -n "$COMMENT_BASE_REF" ]]; then
  if [[ "$COMMENT_BASE_REF" =~ ^0+$ ]] || ! git cat-file -e "${COMMENT_BASE_REF}^{commit}" 2>/dev/null; then
    if git cat-file -e 'HEAD^' 2>/dev/null; then
      COMMENT_BASE_REF='HEAD^'
    else
      COMMENT_BASE_REF=''
    fi
  fi
fi

if [[ -n "$COMMENT_BASE_REF" ]]; then
  category_prefix="${CATEGORIES_DIR#./}"
  if [[ "$category_prefix" != /* ]]; then
    mapfile -t base_files < <(git ls-tree -r --name-only "$COMMENT_BASE_REF" -- "$category_prefix" 2>/dev/null | LC_ALL=C sort)
    for base_file in "${base_files[@]}"; do
      is_category_data_file "$base_file" || continue
      category_name="$(basename "$base_file")"
      while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        trimmed_line="$(trim "$raw_line")"
        [[ -z "$trimmed_line" ]] && continue
        [[ ${trimmed_line:0:1} == '#' ]] && continue
        [[ "$raw_line" == *'#'* ]] && continue
        domain="$(trim "${raw_line%%#*}")"
        [[ -z "$domain" ]] && continue
        legacy_uncommented["$category_name|$domain"]=1
      done < <(git show "$COMMENT_BASE_REF:$base_file" 2>/dev/null || true)
    done
  fi
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

    # Inline-коментар завжди задовольняє вимогу.
    if [[ "$raw_line" == *'#'* ]]; then
      continue
    fi

    # Явний allowlist використовується лише для тимчасових винятків.
    if [[ -n "${allowlist[$entry]:-}" ]]; then
      used_allowlist["$entry"]=1
      continue
    fi

    # У baseline-режимі дозволяємо лише ті uncommented записи, які вже існували в base ref.
    if [[ -n "${legacy_uncommented[$entry]:-}" ]]; then
      continue
    fi

    errors+=("$category_name:$domain")
  done < "$file"
done

if (( ${#errors[@]} )); then
  if [[ -n "$COMMENT_BASE_REF" ]]; then
    echo "Знайдено нові домени без inline-коментарів відносно $COMMENT_BASE_REF:" >&2
  else
    echo "Знайдено домени без коментарів (відсутні в дозволеному списку):" >&2
  fi
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

if [[ -n "$COMMENT_BASE_REF" ]]; then
  echo "Перевірка коментарів успішна: нових uncommented доменів немає."
else
  echo "Перевірка коментарів у категоріях успішна."
fi
