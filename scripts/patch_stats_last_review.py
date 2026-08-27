#!/usr/bin/env python3
from pathlib import Path

path = Path("generate_stats_report.sh")
text = path.read_text(encoding="utf-8")

old = '''  last_check='невідомо'
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    last_check=$(git log -1 --format='%ci' -- "$file" 2>/dev/null || true)
  elif [[ -f "$file" ]]; then
    last_check=$(date -r "$file" '+%F %T' 2>/dev/null || echo 'невідомо')
  fi
  [[ -n "$last_check" ]] || last_check='невідомо'
'''
new = '''  # Category metadata is content-stable across checkout/rebase/squash merges.
  # validate_category_metadata.sh requires @last_review for category files.
  last_check=$(grep -m1 '^# @last_review:' "$file" 2>/dev/null | sed 's/^# @last_review:[[:space:]]*//' || true)
  last_check=$(trim "$last_check")
  [[ -n "$last_check" ]] || last_check='невідомо'
'''

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("last_check block not found")

old_ua = "printf '* Для tracked-файлів дата визначається за останнім Git-комітом; для untracked-файлів використовується filesystem mtime.\\n\\n' >> \"$report_tmp\""
new_ua = "printf '* Дата останньої перевірки категорії береться з метаданих `@last_review`, тому не залежить від checkout/rebase/squash merge.\\n\\n' >> \"$report_tmp\""
if old_ua in text:
    text = text.replace(old_ua, new_ua, 1)
elif new_ua not in text:
    raise SystemExit("UA note not found")

old_en = "printf '* Tracked files use the last Git commit time; untracked files fall back to filesystem mtime.\\n\\n' >> \"$report_en_tmp\""
new_en = "printf '* Category last-check dates come from `@last_review` metadata, so they are stable across checkout/rebase/squash merges.\\n\\n' >> \"$report_en_tmp\""
if old_en in text:
    text = text.replace(old_en, new_en, 1)
elif new_en not in text:
    raise SystemExit("EN note not found")

path.write_text(text, encoding="utf-8")
