#!/usr/bin/env bash
set -euo pipefail

CATEGORIES_DIR=${CATEGORIES_DIR:-categories}
IGNORE_FILE=${IGNORE_FILE:-deprecated.txt}
REQUIRED_FIELDS=(description author last_review)

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

if [[ ! -d "$CATEGORIES_DIR" ]]; then
  echo "Каталог категорій $CATEGORIES_DIR не знайдено" >&2
  exit 1
fi

mapfile -t category_files < <(find "$CATEGORIES_DIR" -maxdepth 1 -type f -name '*.txt' ! -name "$IGNORE_FILE" | LC_ALL=C sort)

if [[ ${#category_files[@]} -eq 0 ]]; then
  echo "У каталозі $CATEGORIES_DIR немає файлів категорій" >&2
  exit 1
fi

errors=()

for file in "${category_files[@]}"; do
  declare -A found=()
  for field in "${REQUIRED_FIELDS[@]}"; do
    found[$field]=''
  done

  while IFS= read -r line || [[ -n "$line" ]]; do
    local_line="$(trim "$line")"
    if [[ -z "$local_line" ]]; then
      continue
    fi
    if [[ "${local_line:0:1}" != '#' ]]; then
      break
    fi
    if [[ "$local_line" =~ ^#\ *@([a-z_]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="$(trim "${BASH_REMATCH[2]}")"
      if [[ -n "${found[$key]+_}" && -z "${found[$key]}" ]]; then
        found[$key]="$value"
      fi
    fi
  done < "$file"

  for field in "${REQUIRED_FIELDS[@]}"; do
    value="${found[$field]}"
    if [[ -z "$value" ]]; then
      errors+=("$file: відсутнє поле @$field")
      continue
    fi
    if [[ "$field" == "last_review" ]]; then
      if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        errors+=("$file: поле @last_review має бути у форматі YYYY-MM-DD")
        continue
      fi
      if ! date -d "$value" '+%F' >/dev/null 2>&1; then
        errors+=("$file: поле @last_review містить некоректну дату")
      fi
    fi
  done

done

if (( ${#errors[@]} )); then
  echo "Помилки метаданих категорій:" >&2
  for message in "${errors[@]}"; do
    echo " - $message" >&2
  done
  exit 1
fi

echo "Метадані категорій валідні для ${#category_files[@]} файлів."
