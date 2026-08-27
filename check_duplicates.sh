#!/usr/bin/env bash
# Скрипт перевіряє списки на дублікати та доступність точних доменів.
# Wildcard-записи (*.example.com) не DNS-resolve'яться: відсутність запису в apex не означає,
# що wildcard endpoint недійсний.
# Використання: ./check_duplicates.sh [файли або каталоги]
set -euo pipefail

skip_dns_check=0
case "${SKIP_DNS_CHECK:-0}" in
  1|true|TRUE|yes|YES)
    skip_dns_check=1
    ;;
esac

is_service_category_file() {
  local name
  name="$(basename "$1")"
  case "$name" in
    comment_allowlist.txt|deprecated.txt)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if (( ! skip_dns_check )); then
  dns_parallelism="${DNS_PARALLELISM:-8}"
  if ! [[ "$dns_parallelism" =~ ^[1-9][0-9]*$ ]]; then
    echo "DNS_PARALLELISM має бути додатним цілим числом" >&2
    exit 1
  fi

  if command -v host >/dev/null 2>&1; then
    lookup_cmd=(host -W1)
  elif command -v nslookup >/dev/null 2>&1; then
    lookup_cmd=(nslookup -timeout=1)
  else
    echo "Не знайдено утиліт host або nslookup" >&2
    exit 1
  fi
fi

check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Файл $file не знайдено" >&2
    return 1
  fi

  if is_service_category_file "$file"; then
    echo "Службовий файл пропущено: $file"
    return 0
  fi

  local dup
  local invalid=0
  # Видаляємо коментарі, щоб дублікати шукалися лише за доменами
  dup=$(grep -v '^\s*#' "$file" \
    | sed '/^\s*$/d' \
    | cut -d '#' -f1 \
    | awk '{print $1}' \
    | sed '/^$/d' \
    | sort \
    | uniq -d)
  if [ -n "$dup" ]; then
    echo "Знайдені дублікати у $file:" >&2
    echo "$dup"
    return 1
  else
    echo "Дублікати не виявлені у $file"
  fi

  if (( ! skip_dns_check )); then
    local dns_failures_dir
    dns_failures_dir=$(mktemp -d)
    local -a dns_pids=()

    while read -r host; do
      [[ -z "$host" ]] && continue
      # Для wildcard не перевіряємо apex/base domain: такий тест дає систематичні false-positive.
      [[ "$host" == \*.* ]] && continue

      (
        if ! "${lookup_cmd[@]}" "$host" 2>&1 |
          grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}|([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}'; then
          printf '%s\n' "$host" > "$dns_failures_dir/$BASHPID"
        fi
      ) &
      dns_pids+=("$!")

      if (( ${#dns_pids[@]} >= dns_parallelism )); then
        for pid in "${dns_pids[@]}"; do
          wait "$pid" || true
        done
        dns_pids=()
      fi
    done < <(grep -v '^\s*#' "$file" | sed '/^\s*$/d' | cut -d '#' -f1 | awk '{print $1}' | sed '/^$/d')

    for pid in "${dns_pids[@]}"; do
      wait "$pid" || true
    done

    if compgen -G "$dns_failures_dir/*" >/dev/null; then
      while read -r host; do
        echo "Недоступний домен: $host" >&2
        invalid=1
      done < <(cat "$dns_failures_dir"/* | LC_ALL=C sort -u)
    fi
    rm -rf "$dns_failures_dir"
  fi

  if (( invalid )); then
    return 1
  fi
}

shopt -s nullglob

if [ "$#" -eq 0 ]; then
  set -- whitelist.txt categories/*.txt
fi

status=0
for target in "$@"; do
  if [ -d "$target" ]; then
    for f in "$target"/*.txt; do
      check_file "$f" || status=1
    done
  else
    check_file "$target" || status=1
  fi
done

exit $status
