#!/usr/bin/env python3
from pathlib import Path

path = Path('generate_stats_report.sh')
text = path.read_text(encoding='utf-8')
old = '''  last_check='невідомо'
  if [[ -f "$file" ]]; then
    last_check=$(date -r "$file" '+%F %T' 2>/dev/null || echo 'невідомо')
  fi
'''
new = '''  last_check='невідомо'
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    last_check=$(git log -1 --format='%ci' -- "$file" 2>/dev/null || true)
  elif [[ -f "$file" ]]; then
    last_check=$(date -r "$file" '+%F %T' 2>/dev/null || echo 'невідомо')
  fi
  [[ -n "$last_check" ]] || last_check='невідомо'
'''
if old not in text:
    raise SystemExit('last_check block not found')
text = text.replace(old, new, 1)
ua_old = "printf '* Дати визначаються за часом останньої модифікації файлу категорії.\\n\\n' >> \"$report_tmp\""
ua_new = "printf '* Для tracked-файлів дата визначається за останнім Git-комітом; для untracked-файлів використовується filesystem mtime.\\n\\n' >> \"$report_tmp\""
if ua_old not in text:
    raise SystemExit('UA note not found')
text = text.replace(ua_old, ua_new, 1)
en_old = "printf '* Dates are derived from the last modified timestamp of each category file.\\n\\n' >> \"$report_en_tmp\""
en_new = "printf '* Tracked files use the last Git commit time; untracked files fall back to filesystem mtime.\\n\\n' >> \"$report_en_tmp\""
if en_old not in text:
    raise SystemExit('EN note not found')
text = text.replace(en_old, en_new, 1)
path.write_text(text, encoding='utf-8')
