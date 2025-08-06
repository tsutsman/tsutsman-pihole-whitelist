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

## Списки за категоріями

Окрім комбінованого файлу `whitelist.txt`, у каталозі `categories/`
розміщено окремі списки за темами. Їх можна імпортувати вибірково,
якщо потрібен лише певний набір доменів.

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

## Генерація загального списку

Скрипт `generate_whitelist.sh` створює файл `whitelist.txt` з усіх
файлів у каталозі `categories/`. Він прибирає коментарі та порожні
рядки, після чого усуває дублікати.

```bash
./generate_whitelist.sh
```

Сформований файл одразу готовий до імпорту в pihole.

## Використання

1. Скопіюйте файл `whitelist.txt` на сервер з pihole.
2. У веб-інтерфейсі pihole відкрийте розділ **Whitelist** та імпортуйте домени з цього файлу.
3. Для автоматичного додавання можна скористатися API pihole.
   Приклад запиту:
   ```bash
   curl -X POST "http://pi.hole/admin/scripts/pi-hole/php/whitelist.php" \
     -d "addfqdn=example.com" -d "token=ВАШ_ТОКЕН"
   ```
4. У розділі **Adlists** можна додати посилання на сирий файл:
   https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt
   Це дозволить pihole автоматично завантажувати оновлення білого списку.

### Приклади для Pi-hole v5 та v6

- **Pi-hole v5**:
  ```bash
  xargs -a whitelist.txt -L1 sudo pihole -w
  ```
- **Pi-hole v6**:
  ```bash
  sudo pihole-FTL whitelist add $(cat whitelist.txt)
  ```

## Перевірка списку

Перед створенням Pull Request запустіть скрипт `check_duplicates.sh`
для кожного списку, який змінювали:

```bash
./check_duplicates.sh categories/ukrainian_services.txt
./check_duplicates.sh whitelist.txt
```

Скрипт повідомить, якщо у вибраному файлі є дублікати рядків.

Ту саму перевірку виконує GitHub Actions при кожному Pull Request, тож
якщо дублікати з'являться, перевірка завершиться помилкою.
Крім того, щотижня запускається окрема перевірка, що повідомляє про можливі проблеми у списках.

## Як зробити внесок

1. Форкніть репозиторій та створіть окрему гілку.
2. Додайте домени до відповідного файлу у `categories/` і вкажіть дату та причину у коментарі.
3. Запустіть `./check_duplicates.sh` без параметрів, щоб переконатися у відсутності дублювань та недоступних доменів.
4. Згенеруйте оновлений `whitelist.txt` через `./generate_whitelist.sh`.
5. Створіть Pull Request з коротким описом змін.

## Ліцензія

Вміст репозиторію поширюється за умовами MIT License. Деталі в файлі `LICENSE`.
