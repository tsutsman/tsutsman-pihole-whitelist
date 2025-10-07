#!/usr/bin/env bash
set -euo pipefail

rm -f whitelist.txt
./generate_whitelist.sh >/dev/null

grep -q '^google.com' whitelist.txt

if [ "$(tail -n +2 whitelist.txt | sort -u)" != "$(tail -n +2 whitelist.txt)" ]; then
  echo "whitelist.txt не відсортовано або містить дублікати" >&2
  exit 1
fi

# Перевірка обробки вибраних файлів
rm -f whitelist.txt
./generate_whitelist.sh categories/google_services.txt categories/ai_services.txt >/dev/null
grep -q '^openai.com' whitelist.txt
if grep -q '^facebook.com' whitelist.txt; then
  echo "До whitelist.txt потрапив зайвий домен facebook.com" >&2
  exit 1
fi

# Перевірка обробки каталогу
mkdir -p categories/_tmpdir
echo "example.com" > categories/_tmpdir/tmp.txt
rm -f whitelist.txt
./generate_whitelist.sh categories/_tmpdir >/dev/null
grep -q '^example.com' whitelist.txt
rm -r categories/_tmpdir

# Перевірка видалення коментарів та дублювання доменів
cat <<'EOF' > categories/_tmp_comments.txt
example.com # перший
example.com # другий
EOF
rm -f whitelist.txt
./generate_whitelist.sh categories/_tmp_comments.txt >/dev/null
if ! grep -q '^example.com$' whitelist.txt; then
  echo "Домен example.com не знайдено без коментарів" >&2
  rm categories/_tmp_comments.txt
  exit 1
fi
if [ "$(grep -c '^example.com$' whitelist.txt)" -ne 1 ]; then
  echo "Домен example.com міститься кілька разів" >&2
  rm categories/_tmp_comments.txt
  exit 1
fi
if tail -n +2 whitelist.txt | grep -q '#'; then
  echo "У whitelist.txt залишилися коментарі" >&2
  rm categories/_tmp_comments.txt
  exit 1
fi
rm categories/_tmp_comments.txt

# Перевірка підключення зовнішніх джерел
mkdir -p sources/generated
echo "external.example" > sources/generated/all_sources.txt
rm -f whitelist.txt
./generate_whitelist.sh >/dev/null
if ! grep -q '^external.example$' whitelist.txt; then
  echo "Зовнішні джерела не було додано до whitelist" >&2
  rm -f sources/generated/all_sources.txt
  rmdir sources/generated 2>/dev/null || true
  exit 1
fi
rm -f sources/generated/all_sources.txt
rmdir sources/generated 2>/dev/null || true

# Перевірка використання змінної OUTFILE
rm -f whitelist_custom.txt
OUTFILE=whitelist_custom.txt ./generate_whitelist.sh >/dev/null
if ! grep -q '^google.com' whitelist_custom.txt; then
  echo "Не вдалося створити whitelist_custom.txt через змінну OUTFILE" >&2
  rm -f whitelist_custom.txt
  exit 1
fi
rm -f whitelist_custom.txt

# Перевірка опції -o/--output з каталогом
rm -rf tmp_output
./generate_whitelist.sh -o tmp_output/alt_whitelist.txt >/dev/null
if ! grep -q '^google.com' tmp_output/alt_whitelist.txt; then
  echo "Опція -o не створила очікуваний файл" >&2
  rm -rf tmp_output
  exit 1
fi
rm -rf tmp_output

echo "Інтеграційний тест успішно пройдено"
