#!/usr/bin/env bash
# Скрипт завантажує зовнішні джерела доменів для білого списку.
# Формат файлу конфігурації: назва|URL|[опис]
# Використання: ./fetch_sources.sh [файл_конфігурації]
set -euo pipefail

CONFIG_FILE=${1:-"sources/default_sources.txt"}
OUT_DIR=${OUT_DIR:-"sources/generated"}
COMBINED_FILE=${COMBINED_FILE:-"$OUT_DIR/all_sources.txt"}

trim() {
  local str="$1"
  str="${str#${str%%[![:space:]]*}}"
  str="${str%${str##*[![:space:]]}}"
  printf '%s' "$str"
}

download() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    echo "Не знайдено curl або wget" >&2
    exit 1
  fi
}

normalize_domains() {
  local src="$1"
  local dest="$2"
  awk '
    function ltrim(s) { sub(/^[[:space:]]+/, "", s); return s }
    function rtrim(s) { sub(/[[:space:]]+$/, "", s); return s }
    function trim(s) { return rtrim(ltrim(s)) }
    function clean_token(token) {
      gsub(/^[*\.]+/, "", token)
      gsub(/\.$/, "", token)
      gsub(/[()]/, "", token)
      return token
    }
    {
      gsub(/\r/, "")
      line=$0
      if (line ~ /^[[:space:]]*([#;!]|$)/) next
      sub(/[#!;].*$/, "", line)
      line=trim(line)
      if (line == "") next
      sub(/^@@\|\|/, "", line)
      sub(/^\|\|/, "", line)
      sub(/\^$/, "", line)
      sub(/^address=/, "", line)
      sub(/^server=/, "", line)
      sub(/^local=/, "", line)
      if (line ~ /^\//) {
        nslash=split(line, slash_parts, "/")
        if (nslash >= 2) {
          line=slash_parts[2]
        }
      }
      if (match(line, /^[0-9A-Fa-f:\.]+[[:space:]]+/)) {
        sub(/^[0-9A-Fa-f:\.]+[[:space:]]+/, "", line)
      }
      sub(/^https?:\/\//, "", line)
      sub(/^\/\//, "", line)
      sub(/\/.*$/, "", line)
      sub(/\?.*$/, "", line)
      gsub(/[,;]/, " ", line)
      n=split(line, parts, /[[:space:]]+/)
      for (i=1; i<=n; i++) {
        token=tolower(trim(parts[i]))
        token=clean_token(token)
        if (token == "") continue
        if (token ~ /^[0-9]+(\.[0-9]+){3}$/) continue
        if (token ~ /^([0-9a-f]{1,4}:){2,}[0-9a-f]{1,4}$/) continue
        if (token ~ /^[a-z0-9_.-]+$/) {
          print token
          break
        }
      }
    }
  ' "$src" | LC_ALL=C sort -u > "$dest"
}

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Файл конфігурації $CONFIG_FILE не знайдено" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

combined_tmp=$(mktemp)
trap 'rm -f "$combined_tmp"' EXIT

: > "$combined_tmp"

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  line=$(trim "$raw_line")
  if [ -z "$line" ] || [[ "$line" == \#* ]]; then
    continue
  fi

  IFS='|' read -r name url _ <<< "$line"
  name=$(trim "${name:-}")
  url=$(trim "${url:-}")

  if [ -z "$name" ] || [ -z "$url" ]; then
    echo "Пропущено некоректний рядок: $raw_line" >&2
    exit 1
  fi

  safe_name=${name,,}
  safe_name=${safe_name// /_}
  safe_name=$(printf '%s' "$safe_name" | tr -c 'a-z0-9._-' '_')
  target_file="$OUT_DIR/$safe_name.txt"

  tmp_source=$(mktemp)
  if ! download "$url" "$tmp_source"; then
    echo "Не вдалося завантажити $url" >&2
    rm -f "$tmp_source"
    exit 1
  fi

  normalize_domains "$tmp_source" "$target_file"
  rm -f "$tmp_source"

  if [ ! -s "$target_file" ]; then
    echo "Файл $target_file порожній після обробки" >&2
    continue
  fi

  cat "$target_file" >> "$combined_tmp"
  echo "Джерело $name збережено у $target_file"
done < "$CONFIG_FILE"

if [ -s "$combined_tmp" ]; then
  mkdir -p "$(dirname "$COMBINED_FILE")"
  LC_ALL=C sort -u "$combined_tmp" > "$COMBINED_FILE"
  echo "Зведений список збережено у $COMBINED_FILE"
else
  : > "$COMBINED_FILE"
  echo "Зведений список порожній" >&2
fi
