#!/usr/bin/env bash
set -euo pipefail

CATEGORIES_DIR=${CATEGORIES_DIR:-categories}
SOURCES_CONFIG=${SOURCES_CONFIG:-sources/default_sources.txt}
GENERATED_DIR=${GENERATED_DIR:-sources/generated}
STATE_FILE=${STATE_FILE:-cleanup_state.txt}
DEPRECATED_FILE=${DEPRECATED_FILE:-$CATEGORIES_DIR/deprecated.txt}
REPORT_FILE=${REPORT_FILE:-docs/data_stats.md}
LOG_FILE=${LOG_FILE:-cleanup.log}

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

lower() {
  printf '%s' "$1" | tr 'A-Z' 'a-z'
}

safe_name() {
  local name
  name=$(lower "$1")
  name=${name// /_}
  printf '%s' "$name" | tr -c 'a-z0-9._-' '_'
}

format_percent() {
  local numerator=$1
  local denominator=$2
  if (( denominator == 0 )); then
    printf '0%%'
  else
    awk -v n="$numerator" -v d="$denominator" 'BEGIN { printf "%.1f%%", (n*100)/d }'
  fi
}

declare -A pending_per_category
declare -A removed_per_category
declare -A failing_domains

if [[ -f "$STATE_FILE" ]]; then
  while read -r domain count rest; do
    [[ -z ${domain:-} ]] && continue
    [[ ${domain:0:1} == '#' ]] && continue
    domain_key=$(lower "$domain")
    category=$(trim "${rest:-}")
    [[ -z "$category" ]] && category="невідомо"
    pending_per_category[$category]=$((pending_per_category[$category]+1))
    failing_domains[$domain_key]=1
  done < "$STATE_FILE"
fi

if [[ -f "$DEPRECATED_FILE" ]]; then
  while IFS= read -r raw_line; do
    line=$(trim "${raw_line%%$'\r'*}")
    [[ -z "$line" ]] && continue
    [[ ${line:0:1} == '#' ]] && continue
    domain=$(trim "${line%%#*}")
    [[ -z "$domain" ]] && continue
    meta=${line#*#}
    category="невідомо"
    if [[ "$meta" == *"category:"* ]]; then
      category=$(printf '%s' "$meta" | awk -F'category:' '{print $2}' | awk '{print $1}')
      category=$(trim "$category")
      [[ -z "$category" ]] && category="невідомо"
    fi
    removed_per_category[$category]=$((removed_per_category[$category]+1))
    domain_key=$(lower "$domain")
    failing_domains[$domain_key]=1
  done < "$DEPRECATED_FILE"
fi

categories_list=()
if [[ -d "$CATEGORIES_DIR" ]]; then
  while IFS= read -r -d '' file; do
    categories_list+=("$file")
  done < <(find "$CATEGORIES_DIR" -type f -name '*.txt' ! -name 'deprecated.txt' -print0 | LC_ALL=C sort -z)
fi

report_tmp=$(mktemp)
trap 'rm -f "$report_tmp"' EXIT

printf '# Статистика whitelist\n\n' >> "$report_tmp"
printf 'Оновлено: %s\n\n' "$(date '+%F %T')" >> "$report_tmp"

printf '## Категорії\n' >> "$report_tmp"
printf '| Категорія | Активних доменів | Проблемні | Частка недоступних | Остання перевірка |\n' >> "$report_tmp"
printf '| --- | ---: | ---: | ---: | --- |\n' >> "$report_tmp"

total_active=0
total_problematic=0
total_removed=0

for file in "${categories_list[@]}"; do
  category_name=$(basename "$file")
  active_count=$(grep -v '^\s*#' "$file" | sed '/^\s*$/d' | wc -l)
  pending=${pending_per_category[$category_name]:-0}
  removed=${removed_per_category[$category_name]:-0}
  problematic=$((pending + removed))
  denom=$((active_count + removed))
  share=$(format_percent "$problematic" "$denom")
  last_check='невідомо'
  if [[ -f "$file" ]]; then
    last_check=$(date -r "$file" '+%F %T' 2>/dev/null || echo 'невідомо')
  fi
  printf '| %s | %d | %d | %s | %s |\n' "$category_name" "$active_count" "$problematic" "$share" "$last_check" >> "$report_tmp"
  total_active=$((total_active + active_count))
  total_problematic=$((total_problematic + problematic))
  total_removed=$((total_removed + removed))
done

printf '\n### Пояснення\n' >> "$report_tmp"
printf '* "Проблемні" = домени, що мають невдалий стан перевірки або були перенесені до `deprecated.txt`.\n' >> "$report_tmp"
printf '* Дати визначаються за часом останньої модифікації файлу категорії.\n\n' >> "$report_tmp"

printf '## Зовнішні джерела\n' >> "$report_tmp"
printf '| Джерело | URL | Доменів | Проблемні | Частка недоступних | Останнє оновлення |\n' >> "$report_tmp"
printf '| --- | --- | ---: | ---: | ---: | --- |\n' >> "$report_tmp"

total_sources_domains=0
total_sources_problematic=0

if [[ -f "$SOURCES_CONFIG" ]]; then
  while IFS= read -r raw_line; do
    line=$(trim "$raw_line")
    [[ -z "$line" ]] && continue
    [[ ${line:0:1} == '#' ]] && continue
    IFS='|' read -r name url _ <<< "$line"
    name=$(trim "${name:-}")
    url=$(trim "${url:-}")
    [[ -z "$name" || -z "$url" ]] && continue
    file_name=$(safe_name "$name")
    source_file="$GENERATED_DIR/$file_name.txt"
    domain_count=0
    problematic=0
    if [[ -f "$source_file" ]]; then
      domain_count=$(wc -l < "$source_file")
      while IFS= read -r domain_line; do
        domain_line=$(trim "$domain_line")
        [[ -z "$domain_line" ]] && continue
        domain_key=$(lower "$domain_line")
        if [[ -n "${failing_domains[$domain_key]:-}" ]]; then
          problematic=$((problematic + 1))
        fi
      done < "$source_file"
    fi
    share=$(format_percent "$problematic" "$domain_count")
    updated='немає даних'
    if [[ -f "$source_file" ]]; then
      updated=$(date -r "$source_file" '+%F %T' 2>/dev/null || echo 'немає даних')
    fi
    printf '| %s | %s | %d | %d | %s | %s |\n' "$name" "$url" "$domain_count" "$problematic" "$share" "$updated" >> "$report_tmp"
    total_sources_domains=$((total_sources_domains + domain_count))
    total_sources_problematic=$((total_sources_problematic + problematic))
  done < "$SOURCES_CONFIG"
fi

printf '\n## Агреговані показники\n' >> "$report_tmp"
printf '* Активних доменів у категоріях: %d.\n' "$total_active" >> "$report_tmp"
printf '* Проблемних доменів у категоріях (стан + deprecated): %d.\n' "$total_problematic" >> "$report_tmp"
printf '* Домени у deprecated.txt: %d.\n' "$total_removed" >> "$report_tmp"
printf '* Домени у зведених джерелах: %d (з них проблемних %d).\n' "$total_sources_domains" "$total_sources_problematic" >> "$report_tmp"

mkdir -p "$(dirname "$REPORT_FILE")"
cp "$report_tmp" "$REPORT_FILE"
