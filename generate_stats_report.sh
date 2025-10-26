#!/usr/bin/env bash
set -euo pipefail

CATEGORIES_DIR=${CATEGORIES_DIR:-categories}
SOURCES_CONFIG=${SOURCES_CONFIG:-sources/default_sources.txt}
GENERATED_DIR=${GENERATED_DIR:-sources/generated}
STATE_FILE=${STATE_FILE:-cleanup_state.txt}
DEPRECATED_FILE=${DEPRECATED_FILE:-$CATEGORIES_DIR/deprecated.txt}
REPORT_FILE=${REPORT_FILE:-docs/data_stats.md}
if [[ -z "${REPORT_FILE_EN:-}" ]]; then
  if [[ "$REPORT_FILE" == *.md ]]; then
    REPORT_FILE_EN="${REPORT_FILE%.md}.en.md"
  else
    REPORT_FILE_EN="${REPORT_FILE}.en.md"
  fi
fi
HTML_REPORT_FILE=${HTML_REPORT_FILE:-docs/dashboard.html}
HISTORY_FILE=${HISTORY_FILE:-docs/data_history.json}
LOG_FILE=${LOG_FILE:-cleanup.log}
REMOVAL_HISTORY_LIMIT=${REMOVAL_HISTORY_LIMIT:-50}

REPORT_TIMESTAMP=${REPORT_TIMESTAMP:-}
REPORT_TIMESTAMP_MODE=${REPORT_TIMESTAMP_MODE:-now}
DASHBOARD_TIMESTAMP=${DASHBOARD_TIMESTAMP:-}
DASHBOARD_TIMESTAMP_MODE=${DASHBOARD_TIMESTAMP_MODE:-$REPORT_TIMESTAMP_MODE}
REPORT_FOOTER_TIMESTAMP=${REPORT_FOOTER_TIMESTAMP:-}
REPORT_FOOTER_TIMESTAMP_MODE=${REPORT_FOOTER_TIMESTAMP_MODE:-now}
HISTORY_TIMESTAMP=${HISTORY_TIMESTAMP:-}
HISTORY_TIMESTAMP_MODE=${HISTORY_TIMESTAMP_MODE:-update}

extract_existing_timestamp() {
  local file="$1"
  local prefix="$2"
  local suffix="${3:-}"
  [[ -f "$file" ]] || return 1
  local line
  line=$(grep -m1 "$prefix" "$file" || true)
  [[ -n "$line" ]] || return 1
  line=$(trim "$line")
  [[ "$line" == "$prefix"* ]] || return 1
  line=${line#"$prefix"}
  if [[ -n "$suffix" && "$line" == *"$suffix"* ]]; then
    line=${line%%"$suffix"*}
  fi
  line=$(trim "$line")
  [[ -n "$line" ]] || return 1
  printf '%s' "$line"
}

determine_report_timestamp() {
  if [[ -n "$REPORT_TIMESTAMP" ]]; then
    printf '%s' "$REPORT_TIMESTAMP"
    return
  fi
  if [[ "$REPORT_TIMESTAMP_MODE" == "keep" ]]; then
    if ts=$(extract_existing_timestamp "$REPORT_FILE" "Оновлено:" ); then
      printf '%s' "$ts"
      return
    fi
    if ts=$(extract_existing_timestamp "$REPORT_FILE_EN" "Updated:" ); then
      printf '%s' "$ts"
      return
    fi
    if ts=$(extract_existing_timestamp "$HTML_REPORT_FILE" "<p>Оновлено:" "</p>"); then
      printf '%s' "$ts"
      return
    fi
  fi
  date '+%F %T'
}

determine_dashboard_timestamp() {
  local fallback="$1"
  if [[ -n "$DASHBOARD_TIMESTAMP" ]]; then
    printf '%s' "$DASHBOARD_TIMESTAMP"
    return
  fi
  if [[ "$DASHBOARD_TIMESTAMP_MODE" == "keep" ]]; then
    if ts=$(extract_existing_timestamp "$HTML_REPORT_FILE" "<p>Оновлено:" "</p>"); then
      printf '%s' "$ts"
      return
    fi
  fi
  printf '%s' "$fallback"
}

determine_footer_timestamp() {
  if [[ -n "$REPORT_FOOTER_TIMESTAMP" ]]; then
    printf '%s' "$REPORT_FOOTER_TIMESTAMP"
    return
  fi
  if [[ "$REPORT_FOOTER_TIMESTAMP_MODE" == "keep" ]]; then
    if ts=$(extract_existing_timestamp "$HTML_REPORT_FILE" "Звіт сформовано скриптом generate_stats_report.sh •" ); then
      printf '%s' "$ts"
      return
    fi
  fi
  date '+%F %T UTC' -u
}

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

html_escape() {
  local text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  text="${text//\"/&quot;}"
  text="${text//\'&#39;}"
  printf '%s' "$text"
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
  while read -r domain _count rest; do
    [[ -z ${domain:-} ]] && continue
    [[ ${domain:0:1} == '#' ]] && continue
    domain_key=$(lower "$domain")
    category=$(trim "${rest:-}")
    [[ -z "$category" ]] && category="невідомо"
    pending_per_category[$category]=$(( ${pending_per_category[$category]:-0} + 1 ))
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
    removed_per_category[$category]=$(( ${removed_per_category[$category]:-0} + 1 ))
    domain_key=$(lower "$domain")
    failing_domains[$domain_key]=1
  done < "$DEPRECATED_FILE"
fi

categories_list=()
categories_rows=()
categories_html=""
sources_rows=()
sources_html=""
if [[ -d "$CATEGORIES_DIR" ]]; then
  while IFS= read -r -d '' file; do
    categories_list+=("$file")
  done < <(find "$CATEGORIES_DIR" -type f -name '*.txt' ! -name 'deprecated.txt' ! -name 'comment_allowlist.txt' -print0 | LC_ALL=C sort -z)
fi

report_tmp=$(mktemp)
report_en_tmp=$(mktemp)
trap 'rm -f "$report_tmp" "$report_en_tmp"' EXIT

report_timestamp="$(determine_report_timestamp)"
dashboard_timestamp="$(determine_dashboard_timestamp "$report_timestamp")"
report_footer_timestamp="$(determine_footer_timestamp)"

printf '# Статистика whitelist\n\n' >> "$report_tmp"
printf '> English version: [docs/data_stats.en.md](data_stats.en.md)\n\n' >> "$report_tmp"
printf 'Оновлено: %s\n\n' "$report_timestamp" >> "$report_tmp"

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
  categories_rows+=("$category_name|$active_count|$problematic|$share|$last_check")
  categories_html+=$'\n<tr>'
  categories_html+="<td>$(html_escape "$category_name")</td>"
  categories_html+="<td class=\"num\">$active_count</td>"
  categories_html+="<td class=\"num\">$problematic</td>"
  categories_html+="<td class=\"num\">$share</td>"
  categories_html+="<td>$(html_escape "$last_check")</td>"
  categories_html+=$'</tr>'
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
    sources_rows+=("$name|$url|$domain_count|$problematic|$share|$updated")
    sources_html+=$'\n<tr>'
    sources_html+="<td>$(html_escape "$name")</td>"
    sources_html+="<td><a href=\"$(html_escape "$url")\" target=\"_blank\" rel=\"noopener\">$(html_escape "$url")</a></td>"
    sources_html+="<td class=\"num\">$domain_count</td>"
    sources_html+="<td class=\"num\">$problematic</td>"
    sources_html+="<td class=\"num\">$share</td>"
    sources_html+="<td>$(html_escape "$updated")</td>"
    sources_html+=$'</tr>'
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

printf '# Whitelist statistics\n\n' >> "$report_en_tmp"
printf '> Ukrainian version: [docs/data_stats.md](data_stats.md)\n\n' >> "$report_en_tmp"
printf 'Updated: %s\n\n' "$report_timestamp" >> "$report_en_tmp"

printf '## Categories\n' >> "$report_en_tmp"
printf '| Category | Active domains | Problematic | Unavailable share | Last check |\n' >> "$report_en_tmp"
printf '| --- | ---: | ---: | ---: | --- |\n' >> "$report_en_tmp"
for row in "${categories_rows[@]}"; do
  IFS='|' read -r c_name c_active c_problematic c_share c_last <<< "$row"
  printf '| %s | %s | %s | %s | %s |\n' "$c_name" "$c_active" "$c_problematic" "$c_share" "$c_last" >> "$report_en_tmp"
done

printf '\n### Notes\n' >> "$report_en_tmp"
printf '* “Problematic” = domains that failed verification or were moved to `deprecated.txt`.\n' >> "$report_en_tmp"
printf '* Dates are derived from the last modified timestamp of each category file.\n\n' >> "$report_en_tmp"

printf '## External sources\n' >> "$report_en_tmp"
printf '| Source | URL | Domains | Problematic | Unavailable share | Last update |\n' >> "$report_en_tmp"
printf '| --- | --- | ---: | ---: | ---: | --- |\n' >> "$report_en_tmp"
if [[ ${#sources_rows[@]} -eq 0 ]]; then
  printf '| — | — | 0 | 0 | 0%% | no data |\n' >> "$report_en_tmp"
else
  for row in "${sources_rows[@]}"; do
    IFS='|' read -r s_name s_url s_domains s_problematic s_share s_updated <<< "$row"
    printf '| %s | %s | %s | %s | %s | %s |\n' "$s_name" "$s_url" "$s_domains" "$s_problematic" "$s_share" "$s_updated" >> "$report_en_tmp"
  done
fi

printf '\n## Aggregated metrics\n' >> "$report_en_tmp"
printf '* Active domains across categories: %d.\n' "$total_active" >> "$report_en_tmp"
printf '* Problematic domains in categories (status + deprecated): %d.\n' "$total_problematic" >> "$report_en_tmp"
printf '* Domains in `deprecated.txt`: %d.\n' "$total_removed" >> "$report_en_tmp"
printf '* Domains in combined external sources: %d (problematic: %d).\n' "$total_sources_domains" "$total_sources_problematic" >> "$report_en_tmp"

mkdir -p "$(dirname "$REPORT_FILE_EN")"
cp "$report_en_tmp" "$REPORT_FILE_EN"

mkdir -p "$(dirname "$HISTORY_FILE")"

env HISTORY_TIMESTAMP_MODE="$HISTORY_TIMESTAMP_MODE" HISTORY_TIMESTAMP="$HISTORY_TIMESTAMP" python3 - "$HISTORY_FILE" <<PY
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

history_path = Path(sys.argv[1])
mode = os.environ.get("HISTORY_TIMESTAMP_MODE", "update").lower()
custom_ts = os.environ.get("HISTORY_TIMESTAMP", "")

timestamp = custom_ts or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
entry = {
    "timestamp": timestamp,
    "active_domains": $total_active,
    "problematic_domains": $total_problematic,
    "deprecated_domains": $total_removed,
    "sources_domains": $total_sources_domains,
    "sources_problematic": $total_sources_problematic,
}

data = []
if history_path.exists():
    try:
        data = json.loads(history_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = []

metrics_match = False
if data:
    last = data[-1]
    metrics_match = (
        last.get("active_domains") == entry["active_domains"]
        and last.get("problematic_domains") == entry["problematic_domains"]
        and last.get("deprecated_domains") == entry["deprecated_domains"]
        and last.get("sources_domains") == entry["sources_domains"]
        and last.get("sources_problematic") == entry["sources_problematic"]
    )
    if metrics_match:
        if mode == "keep" and not custom_ts:
            entry["timestamp"] = last.get("timestamp", entry["timestamp"])
        data[-1] = entry
    else:
        data.append(entry)
else:
    data.append(entry)

data = data[-365:]
history_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

history_json=$(cat "$HISTORY_FILE" 2>/dev/null || echo '[]')

if [[ -z "${categories_html:-}" ]]; then
  categories_html='<tr><td colspan="5">Немає доступних категорій</td></tr>'
fi

if [[ -z "${sources_html:-}" ]]; then
  sources_html='<tr><td colspan="6">Немає даних про зовнішні джерела</td></tr>'
fi

removals_html=""
if [[ -f "$LOG_FILE" && -s "$LOG_FILE" ]]; then
  while IFS= read -r raw_line; do
    line=$(trim "${raw_line%%$'\r'*}")
    [[ -z "$line" ]] && continue
    removals_html+=$'\n<li><code>'"$(html_escape "$line")"'</code></li>'
  done < <(tail -n "$REMOVAL_HISTORY_LIMIT" "$LOG_FILE")
else
  removals_html='<li>Журнал порожній або недоступний.</li>'
fi

html_tmp=$(mktemp)
cat > "$html_tmp" <<EOF
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="utf-8">
  <title>Моніторинг whitelist</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="preconnect" href="https://cdn.jsdelivr.net">
  <style>
    body { font-family: "Inter", system-ui, -apple-system, sans-serif; margin: 2rem; background: #f8fafc; color: #0f172a; }
    h1 { margin-bottom: 1rem; }
    section { background: white; border-radius: 16px; padding: 1.5rem; box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08); margin-bottom: 2rem; }
    table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
    th, td { padding: 0.6rem 0.8rem; border-bottom: 1px solid #e2e8f0; text-align: left; }
    th { background: #f1f5f9; text-transform: uppercase; letter-spacing: 0.04em; font-size: 0.75rem; color: #475569; }
    td.num { text-align: right; font-variant-numeric: tabular-nums; }
    .grid { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); margin-top: 1rem; }
    .metric { padding: 1rem; border-radius: 12px; background: linear-gradient(135deg, #2563eb0d, #38bdf80d); border: 1px solid #e2e8f0; }
    .metric span { display: block; font-size: 0.85rem; color: #475569; margin-bottom: 0.4rem; }
    .metric strong { font-size: 1.6rem; font-variant-numeric: tabular-nums; }
    ul.log { max-height: 280px; overflow-y: auto; list-style: none; padding: 0; margin: 0; }
    ul.log li { padding: 0.4rem 0; border-bottom: 1px dashed #cbd5f5; font-family: "Fira Code", "JetBrains Mono", monospace; font-size: 0.85rem; }
    ul.log code { background: transparent; color: #1e293b; }
    footer { text-align: center; color: #64748b; margin-top: 3rem; font-size: 0.85rem; }
    @media (prefers-color-scheme: dark) {
      body { background: #0f172a; color: #e2e8f0; }
      section { background: #1e293b; box-shadow: none; }
      th { background: rgba(148, 163, 184, 0.15); color: #cbd5f5; }
      td { border-bottom-color: rgba(148, 163, 184, 0.2); }
      .metric { background: rgba(37, 99, 235, 0.1); border-color: rgba(148, 163, 184, 0.2); }
      ul.log li { border-bottom-color: rgba(148, 163, 184, 0.2); }
    }
  </style>
</head>
<body>
  <h1>Моніторинг білого списку Pi-hole</h1>
  <p>Оновлено: $dashboard_timestamp</p>

  <section>
    <h2>Ключові показники</h2>
    <div class="grid">
      <div class="metric"><span>Активних доменів</span><strong>$total_active</strong></div>
      <div class="metric"><span>Проблемні домени</span><strong>$total_problematic</strong></div>
      <div class="metric"><span>Домени у deprecated</span><strong>$total_removed</strong></div>
      <div class="metric"><span>Джерела (доменів)</span><strong>$total_sources_domains</strong></div>
    </div>
    <canvas id="historyChart" height="160" style="margin-top: 1.5rem;"></canvas>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script type="application/json" id="history-data">$history_json</script>
    <script>
      const historyRaw = document.getElementById('history-data').textContent || '[]';
      let historyData = [];
      try { historyData = JSON.parse(historyRaw); } catch (error) { historyData = []; }
      const labels = historyData.map((item) => item.timestamp);
      const activeSeries = historyData.map((item) => item.active_domains);
      const problematicSeries = historyData.map((item) => item.problematic_domains);
      const canvas = document.getElementById('historyChart');
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

      if (!labels.length) {
        const placeholder = document.createElement('p');
        placeholder.textContent = 'Недостатньо даних для побудови графіка.';
        placeholder.style.marginTop = '1rem';
        canvas.replaceWith(placeholder);
      } else {
        const ctx = canvas.getContext('2d');
        const axisColor = mediaQuery.matches ? '#cbd5f5' : '#475569';
        const legendColor = mediaQuery.matches ? '#e2e8f0' : '#1e293b';

        const chartInstance = new Chart(ctx, {
          type: 'line',
          data: {
            labels,
            datasets: [
              { label: 'Активні домени', data: activeSeries, borderColor: '#2563eb', backgroundColor: 'rgba(37,99,235,0.2)', tension: 0.25, fill: true },
              { label: 'Проблемні домени', data: problematicSeries, borderColor: '#ef4444', backgroundColor: 'rgba(239,68,68,0.2)', tension: 0.25, fill: true }
            ]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
              x: { ticks: { color: axisColor } },
              y: { ticks: { color: axisColor }, beginAtZero: true }
            },
            plugins: {
              legend: { labels: { color: legendColor } }
            }
          }
        });

        const applyTheme = () => {
          const darkMode = mediaQuery.matches;
          const tickColor = darkMode ? '#cbd5f5' : '#475569';
          const labelColor = darkMode ? '#e2e8f0' : '#1e293b';
          chartInstance.options.scales.x.ticks.color = tickColor;
          chartInstance.options.scales.y.ticks.color = tickColor;
          chartInstance.options.plugins.legend.labels.color = labelColor;
          chartInstance.update();
        };

        if (mediaQuery.addEventListener) {
          mediaQuery.addEventListener('change', applyTheme);
        } else if (mediaQuery.addListener) {
          mediaQuery.addListener(applyTheme);
        }
        applyTheme();
      }
    </script>
  </section>

  <section>
    <h2>Категорії</h2>
    <table>
      <thead>
        <tr><th>Категорія</th><th>Активні</th><th>Проблемні</th><th>Частка недоступних</th><th>Остання перевірка</th></tr>
      </thead>
      <tbody>
        $categories_html
      </tbody>
    </table>
  </section>

  <section>
    <h2>Зовнішні джерела</h2>
    <table>
      <thead>
        <tr><th>Назва</th><th>URL</th><th>Доменів</th><th>Проблемні</th><th>Частка недоступних</th><th>Останнє оновлення</th></tr>
      </thead>
      <tbody>
        $sources_html
      </tbody>
    </table>
  </section>

  <section>
    <h2>Журнал видалень</h2>
    <ul class="log">
      $removals_html
    </ul>
  </section>

  <footer>
    Звіт сформовано скриптом generate_stats_report.sh • $report_footer_timestamp
  </footer>
</body>
</html>
EOF

mkdir -p "$(dirname "$HTML_REPORT_FILE")"
cp "$html_tmp" "$HTML_REPORT_FILE"
rm -f "$html_tmp"
