#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/strict/categories"
echo 'legacy.example' > "$tmpdir/strict/categories/demo.txt"
: > "$tmpdir/strict/categories/comment_allowlist.txt"

if CATEGORIES_DIR="$tmpdir/strict/categories" \
  ALLOWLIST_FILE="$tmpdir/strict/categories/comment_allowlist.txt" \
  "$project_root/check_category_comments.sh" >/dev/null 2>&1; then
  echo "Strict-режим мав відхилити домен без коментаря" >&2
  exit 1
fi

echo 'demo.txt|legacy.example' > "$tmpdir/strict/categories/comment_allowlist.txt"
CATEGORIES_DIR="$tmpdir/strict/categories" \
  ALLOWLIST_FILE="$tmpdir/strict/categories/comment_allowlist.txt" \
  "$project_root/check_category_comments.sh" >/dev/null

# Baseline-режим: старий uncommented запис дозволено, новий — ні.
mkdir -p "$tmpdir/repo/categories"
cd "$tmpdir/repo"
git init -q
git config user.name test
git config user.email test@example.invalid
echo 'legacy.example' > categories/demo.txt
cat > categories/comment_allowlist.txt <<'EOF'
# empty baseline allowlist
EOF
git add categories
git commit -qm baseline
base_ref=$(git rev-parse HEAD)

echo 'new.example' >> categories/demo.txt
if COMMENT_BASE_REF="$base_ref" CATEGORIES_DIR=categories ALLOWLIST_FILE=categories/comment_allowlist.txt \
  "$project_root/check_category_comments.sh" >/dev/null 2>&1; then
  echo "Baseline-режим мав відхилити новий домен без коментаря" >&2
  exit 1
fi

cat > categories/demo.txt <<'EOF'
legacy.example
new.example # documented new endpoint
EOF
COMMENT_BASE_REF="$base_ref" CATEGORIES_DIR=categories ALLOWLIST_FILE=categories/comment_allowlist.txt \
  "$project_root/check_category_comments.sh" >/dev/null

echo "Перевірка коментарів категорій пройшла успішно"
