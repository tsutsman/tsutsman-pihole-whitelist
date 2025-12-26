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

## Розширений профіль для комфортного користування

Якщо використовуєте агресивні динамічні блоклисти і хочете мінімізувати хибні спрацювання, імпортуйте готовий файл `categories/comfort_pack.txt` разом із ключовими категоріями:

- `categories/base.txt` — базові домени (GitHub, Google, Microsoft тощо).
- `categories/google_services.txt` — повний набір доменів Google, включно з GVT та Google Play.
- `categories/extended_services.txt` — допоміжні домени для месенджерів, соцмереж і платіжних систем.
- `categories/web_resources.txt` — популярні CDN для скриптів, шрифтів та стилів.
- `categories/comfort_pack.txt` — CDN (Akamai, CloudFront, Fastly), мультимедійні хости Facebook/Instagram/WhatsApp та Google Cloud Storage.
- За потреби додайте профільні категорії: `categories/messengers.txt`, `categories/social_networks.txt`, `categories/streaming_services.txt`, `categories/ecommerce.txt`.

Щоб швидко зібрати розширений файл, скористайтеся скриптом:

```bash
./generate_whitelist.sh \
  categories/base.txt \
  categories/google_services.txt \
  categories/extended_services.txt \
  categories/web_resources.txt \
  categories/comfort_pack.txt \
  categories/messengers.txt \
  categories/social_networks.txt \
  categories/streaming_services.txt
```

Отриманий `whitelist.txt` покриє основні CDN, мобільні апдейти, завантаження з Google Play та мультимедіа соцмереж, що часто потрапляють під динамічні блоклисти.

## Як застосувати

1. Додайте наведені домени або відповідні файли категорій до Pi-hole через веб-інтерфейс (Whitelist → Import) чи за допомогою CLI.
2. Щоб згенерувати комбінований файл лише з потрібних категорій, виконайте:
   ```bash
   ./generate_whitelist.sh categories/base.txt categories/apple.txt categories/cloud_storage.txt
   ```
3. Імпортуйте сформований файл `whitelist.txt` у Pi-hole або застосуйте його скриптом `apply_whitelist.sh`.
