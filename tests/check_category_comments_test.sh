#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

"$project_root/check_category_comments.sh" >/dev/null

echo "Перевірка коментарів категорій пройшла успішно"
