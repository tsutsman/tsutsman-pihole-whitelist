# Рекомендовані домени для білого списку

Цей список допоможе швидко додати основні легітимні ресурси, які найчастіше блокуються Pi-hole при використанні агресивних блок-листів. Використовуйте його як відправну точку, а за потреби розширюйте категоріями з каталогу `categories/`.

## Базовий перелік (обовʼязково)

| Домен | Навіщо дозволяти |
| --- | --- |
| `api.github.com` | API GitHub для оновлень репозиторіїв та інструментів CLI. |
| `github.com` / `raw.githubusercontent.com` / `status.github.com` | Вебінтерфейс, сирі файли та статус-сервіс GitHub. |
| `apple.com` | App Store, iCloud та активація пристроїв Apple. |
| `microsoft.com` | Основні сервіси Microsoft (включно з OneDrive). |
| `google.com` | Пошук і підписки Google. |
| `youtube.com` | Відеохостинг та вбудовані плеєри. |
| `cloudflare.com` | CDN та DNS-послуги Cloudflare. |
| `wikipedia.org` | Доступ до енциклопедії. |

## Коли потрібні додаткові категорії

- **Apple iCloud/App Store**: додайте `categories/apple.txt`, щоб покрити CDN і допоміжні хости Apple (онлайн-бекапи, завантаження застосунків).
- **Microsoft OneDrive/Office 365**: імпортуйте `categories/microsoft_onedrive.txt` для синхронізації файлів та активації продуктів.
- **Хмарні сховища**: `categories/cloud_storage.txt` містить домени Google Drive, MEGA, Synology та інших провайдерів.
- **Комунікації (месенджери, конференції)**: оберіть `categories/messengers.txt` і `categories/office_collaboration.txt`, щоб уникнути блокування Telegram, WhatsApp, Zoom чи Microsoft Teams.
- **Соцмережі та стрімінги**: використовуйте `categories/social_networks.txt` та `categories/streaming_services.txt`, якщо потрібні YouTube-альтернативи, Netflix чи Spotify.
- **Українські сервіси та банки**: додайте `categories/ukrainian_services.txt` і `categories/international_banks.txt`, щоб не блокувати платежі та онлайн-банкінг.
- **Синхронізація часу**: `categories/ntp_servers.txt` корисний для пристроїв, яким потрібний точний час.

## Як застосувати

1. Додайте наведені домени або відповідні файли категорій до Pi-hole через веб-інтерфейс (Whitelist → Import) чи за допомогою CLI.
2. Щоб згенерувати комбінований файл лише з потрібних категорій, виконайте:
   ```bash
   ./generate_whitelist.sh categories/base.txt categories/apple.txt categories/cloud_storage.txt
   ```
3. Імпортуйте сформований файл `whitelist.txt` у Pi-hole або застосуйте його скриптом `apply_whitelist.sh`.
