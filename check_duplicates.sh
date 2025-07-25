#!/usr/bin/env bash
# Скрипт перевіряє файл whitelist.txt на дублікати рядків.
# Використання: ./check_duplicates.sh [файл]

FILE=${1:-whitelist.txt}

if [ ! -f "$FILE" ]; then
  echo "Файл $FILE не знайдено" >&2
  exit 1
fi

DUP=$(sort "$FILE" | uniq -d)
if [ -n "$DUP" ]; then
  echo "Знайдені дублікати:" >&2
  echo "$DUP"
  exit 1
else
  echo "Дублікати не виявлені"
fi
