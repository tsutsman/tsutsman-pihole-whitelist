# Статус робіт та доступні інструменти

Цей документ фіксує, що вже реалізовано для підтримки whitelist-проєкту, і підказує, як продовжувати розвиток.

## Виконані вдосконалення

- [x] **Регулярна статистика списків.** `generate_stats_report.sh` формує Markdown-звіт (`docs/data_stats.md`), англомовну версію, історію `docs/data_history.json` та дашборд `docs/dashboard.html`. У CI додано перевірку, що ці файли залишаються актуальними.
- [x] **Стійке завантаження зовнішніх джерел.** `fetch_sources.sh` підтримує кеш, повторні спроби, TTL, а тести `tests/fetch_sources_test.sh` перевіряють повернення до кешу та нормалізацію даних.
- [x] **Розширені сценарії для shell-скриптів.** Тести `tests/cleanup_whitelist_test.sh` і `tests/check_duplicates_test.sh` покривають порожні файли, повторні запуски, прапорці `PARALLEL` та `SKIP_DNS_CHECK`.
- [x] **Повноцінний CLI для збірки білого списку.** `build_whitelist.sh` підтримує вибір категорій, додаткові шляхи, увімкнення/вимкнення зовнішніх джерел, опцію `--output` та інтегрується з `apply_whitelist.sh`; покрито тестом `tests/build_whitelist_test.sh`.
- [x] **REST/CGI-бекенд для веб-інтерфейсу.** `whitelist_builder_api.py` надає ендпоінти `/api/categories`, `/api/build`, `/downloads/*`, має логування та smoke-тест `tests/whitelist_builder_api_test.sh`.
- [x] **Оновлений CI.** `.github/workflows/ci.yml` запускає всі shell-тести, лінти, smoke-тести API та перевіряє, що статистичні звіти згенеровані скриптом і не відстають від коду.
- [x] **Документація веб-інтерфейсу та процесів.** README, `docs/web_interface_plan.md` та `docs/web_interface_deployment.md` містять інструкції з розгортання, а шаблон `.github/pull_request_template.md` описує вимоги до ревʼю доменів.
- [x] **Метадані категорій та експорт у сторонні системи.** Скрипт `validate_category_metadata.sh` контролює опис/автора/дату ревізії, а `export_whitelist.sh` генерує формати для AdGuard Home і pfBlockerNG.

## Поточні рекомендації

- Підтримувати `docs/data_stats.md` у синхронізації з категоріями (CI вже підкаже про відхилення).
- Розширювати `docs/data_history.json` регулярним запуском `generate_stats_report.sh`, щоб дашборд містив релевантну хронологію.
- Перед додаванням нових категорій запускати `validate_category_metadata.sh`, `check_category_comments.sh` і `check_duplicates.sh` — це пришвидшує ревʼю.
- Для нових інтеграцій DNS-експортів додавати формати в `export_whitelist.sh` разом із тестами.
