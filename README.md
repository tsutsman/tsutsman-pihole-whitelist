# tsutsman-pihole-whitelist

> Англійська версія цього опису доступна у файлі [README.en.md](README.en.md).

Цей репозиторій містить базовий список доменів, які можна додати до білого списку pihole.
Основний список розміщено у файлі `whitelist.txt`. Він включає, зокрема, домени для коректної роботи Microsoft OneDrive.
Нещодавно до списку додано популярні українські сервіси для коректної роботи місцевих сайтів та банків.
Додано підтримку основних сервісів Apple для iCloud та App Store.
Тепер також у списку присутні домени для Google Drive та MEGA, щоб не блокувати роботу цих хмарних сховищ.
Додано хости Synology та популярні сервери точного часу (NTP) для коректної синхронізації часу.
Також додано домени популярних месенджерів, додаткових хмарних сховищ та українських банків.
Окремим розділом тепер додані домени українських державних порталів.

Кожен домен у списках супроводжується коментарем із датою та причиною додавання до whitelist для повної прозорості.

## Списки за категоріями

Окрім комбінованого файлу `whitelist.txt`, у каталозі `categories/`
розміщено окремі списки за темами. Їх можна імпортувати вибірково,
якщо потрібен лише певний набір доменів.

### Власні категорії

Можна створювати власні файли у каталозі `categories/` або в окремому каталозі й передавати його до скриптів. Назва файлу може бути довільною, головне — використовувати розширення `.txt` та додавати пояснювальні коментарі.

Доступні такі файли:

- `base.txt` — базові домени, що найчастіше використовуються;
- `apple.txt` — адреси сервісів Apple;
- `microsoft_onedrive.txt` — домени Microsoft і OneDrive;
- `ukrainian_services.txt` — популярні українські сервіси та банки;
- `cloud_storage.txt` — хмарні сховища (Google Drive, MEGA, Synology тощо);
- `messengers.txt` — домени Telegram, WhatsApp, Discord;
- `ntp_servers.txt` — сервери точного часу (NTP).
- `gaming.txt` — домени популярних ігор і сервісів (Steam, Epic Games, Riot, Blizzard, Wargaming).
- `web_resources.txt` — CDN та хости скриптів і стилів для вигляду сайтів.
- `office_collaboration.txt` — Zoom, Slack та Microsoft Teams.
- `ai_services.txt` — популярні AI-сервіси.
- `social_networks.txt` — домени популярних соцмереж.
- `streaming_services.txt` — відео- та музичні стрімінги.
- `ecommerce.txt` — міжнародні майданчики електронної торгівлі.
- `educational_resources.txt` — корисні освітні портали.
- `news_media.txt` — популярні новинні ресурси.
- `international_banks.txt` — міжнародні платіжні сервіси.

### Вибірковий імпорт та генерація

Кожен файл із каталогу `categories/` можна застосовувати окремо.

- **Через веб-інтерфейс:** у розділі **Whitelist** натисніть **Import** і завантажте потрібний файл, наприклад `categories/apple.txt`.
- **Через командний рядок Linux:**
  - Pi-hole v5:
    ```bash
    xargs -a categories/apple.txt -L1 sudo pihole -w
    ```
  - Pi-hole v6:
    ```bash
    sudo pihole-FTL whitelist add $(cat categories/apple.txt)
    ```

Щоб зібрати власний `whitelist.txt` лише з вибраних файлів чи каталогів, передайте їх до скрипту. Коментарі та дублікати будуть автоматично видалені:

```bash
./generate_whitelist.sh categories/base.txt categories/apple.txt
```

Сформований файл можна імпортувати будь-яким із наведених способів. Якщо ви не працюєте з командним рядком, просто скачайте потрібні файли чи згенерований `whitelist.txt` і додайте їх через веб-інтерфейс.

## Генерація загального списку

Скрипт `generate_whitelist.sh` створює файл `whitelist.txt` з усіх
файлів у каталозі `categories/` або з указаних аргументів. Він
прибирає коментарі та порожні рядки, після чого усуває дублікати.

```bash
./generate_whitelist.sh              # всі категорії
./generate_whitelist.sh categories/cloud_storage.txt extra_dir/  # вибіркові файли чи каталоги
```

Сформований файл одразу готовий до імпорту в pihole.

## Зовнішні джерела доменів

Щоб не шукати вручну додаткові домени для білого списку, скористайтеся
скриптом `fetch_sources.sh`. Він читає перелік джерел із файлу
`sources/default_sources.txt` (або іншого, переданого як аргумент),
завантажує списки доменів і перетворює їх у формати, сумісні з Pi-hole.

```bash
./fetch_sources.sh                     # стандартні джерела
./fetch_sources.sh my_sources.txt      # власний перелік
```

Кожен рядок у файлі джерел має формат `назва|URL|коментар`. Назва
використовується для створення файлу у каталозі `sources/generated/`,
де зберігаються результати. Після успішного запуску додатково
створюється файл `sources/generated/all_sources.txt` із загальним
переліком доменів.

Скрипт `generate_whitelist.sh` автоматично підключає цей файл до
генерації білого списку. Якщо потрібно вимкнути зовнішні джерела або
вказати інше розташування, можна скористатися змінними середовища:

```bash
INCLUDE_EXTERNAL_SOURCES=0 ./generate_whitelist.sh
SOURCES_COMBINED=custom.txt ./generate_whitelist.sh
```

## Використання

1. Скопіюйте файл `whitelist.txt` на сервер з pihole.
2. У веб-інтерфейсі pihole відкрийте розділ **Whitelist** та імпортуйте домени з цього файлу.
3. Або скористайтеся скриптом `apply_whitelist.sh`, який прочитає файл (за замовчуванням `whitelist.txt`) і додасть домени до білого списку:
   ```bash
   ./apply_whitelist.sh
   ./apply_whitelist.sh custom.txt  # інший файл
   ```
4. Для автоматичного додавання можна скористатися API pihole.
   Приклад запиту:
   ```bash
   curl -X POST "http://pi.hole/admin/scripts/pi-hole/php/whitelist.php" \
     -d "addfqdn=example.com" -d "token=ВАШ_ТОКЕН"
   ```
5. У розділі **Adlists** можна додати посилання на сирий файл:
   https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt
   Це дозволить pihole автоматично завантажувати оновлення білого списку (див. розділ [«Автоматичне оновлення білого списку»](#автоматичне-оновлення-білого-списку)).

### Приклади для Pi-hole v5 та v6

- **Pi-hole v5**:
  ```bash
  xargs -a whitelist.txt -L1 sudo pihole -w
  ```
- **Pi-hole v6**:
  ```bash
  sudo pihole-FTL whitelist add $(cat whitelist.txt)
  ```

## Автоматичне оновлення білого списку

Список можна підтримувати актуальним двома способами.

1. **Додавання URL до Adlists**  
   Додайте посилання на сирий `whitelist.txt` у розділ **Adlists** веб-інтерфейсу або виконайте команду:
   ```bash
   sudo pihole -a adlist add https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt "tsutsman whitelist"
   sudo pihole updateGravity
   ```
   Під час кожного запуску `pihole updateGravity` (зазвичай через вбудований cron) Pi-hole завантажуватиме свіжу версію списку.

2. **Власне cron-завдання**
   За потреби можна налаштувати окремий cron, що періодично запускає `update_and_apply.sh`:
   ```bash
   # щоденний запуск о 03:00
   0 3 * * * /srv/pihole-whitelist/update_and_apply.sh >> /var/log/pihole-whitelist.log 2>&1
   ```
   Скрипт завантажить актуальний `whitelist.txt`, застосує його до Pi-hole та занотує подію в журнал. URL джерела можна змінити через змінну `REPO_URL`, а шлях до журналу — через `LOG_FILE`.

## Перевірка списку

Перед створенням Pull Request запустіть скрипт `check_duplicates.sh`.
Він перевіряє дублікати та доступність доменів за допомогою `host` або `nslookup`.
Можна передати конкретні файли чи каталоги або нічого — тоді скрипт обробить усі списки.

```bash
./check_duplicates.sh categories/ukrainian_services.txt
./check_duplicates.sh whitelist.txt
./check_duplicates.sh                   # перевірити всі списки
```

Скрипт повідомить про дублікати та недоступні домени.

Ту саму перевірку виконує GitHub Actions при кожному Pull Request, тож
якщо дублікати з'являться, перевірка завершиться помилкою.
Крім того, щотижня запускається окрема перевірка, що повідомляє про можливі проблеми у списках.

## Очищення недоступних доменів

Скрипт `cleanup_whitelist.sh` регулярно перевіряє домени у каталозі `categories`.
Якщо домен недоступний впродовж кількох запусків поспіль, він переноситься до `categories/deprecated.txt` для подальшого аналізу.
Поведінку можна налаштувати змінними середовища:

- `CATEGORIES_DIR` — шлях до каталогу зі списками (за замовчуванням `categories`);
- `STATE_FILE` — файл для зберігання кількості невдалих перевірок (за замовчуванням `cleanup_state.txt`);
- `THRESHOLD` — скільки разів поспіль домен має бути недоступним, щоб потрапити до `deprecated.txt` (за замовчуванням `3`);
- `DEPRECATED_FILE` — файл, куди додаються вилучені домени (за замовчуванням `categories/deprecated.txt`).

```bash
THRESHOLD=2 ./cleanup_whitelist.sh

# приклад із власним каталогом та журналом
CATEGORIES_DIR=my_lists THRESHOLD=5 LOG_FILE=my.log ./cleanup_whitelist.sh
```

## Як зробити внесок

1. Форкніть репозиторій та створіть окрему гілку.
2. Додайте домени до відповідного файлу у `categories/` і вкажіть дату та причину у коментарі.
3. Запустіть `./check_duplicates.sh` без параметрів, щоб переконатися у відсутності дублювань та недоступних доменів.
4. Згенеруйте оновлений `whitelist.txt` через `./generate_whitelist.sh`.
5. Створіть Pull Request з коротким описом змін.

## Ліцензія

Вміст репозиторію поширюється за умовами MIT License. Деталі в файлі `LICENSE`.
