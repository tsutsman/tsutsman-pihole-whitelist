# Розгортання веб-інтерфейсу Whitelist Builder

Цей документ описує, як додати до Pi-hole веб-розділ для вибіркової генерації whitelist-файлів.
Рішення базується на скриптах [`build_whitelist.sh`](../build_whitelist.sh) та
[`whitelist_builder_api.py`](../whitelist_builder_api.py), а також статичній сторінці
[`web/whitelist_builder.html`](../web/whitelist_builder.html).

## 1. Передумови

- Pi-hole v5 або v6, доступ до SSH та привілеї адміністратора.
- Встановлений `python3` (версія 3.9+ рекомендується) і стандартні утиліти (`bash`, `git`).
- У стандартній інсталяції Pi-hole використовується `lighttpd` — нижче наведено приклади саме для нього.

## 2. Підготовка робочого каталогу

1. Склонуйте репозиторій і встановіть права:
   ```bash
   sudo mkdir -p /srv/pihole-whitelist
   sudo chown "$USER":"$USER" /srv/pihole-whitelist
   git clone https://github.com/tsutsman/pihole-whitelist.git /srv/pihole-whitelist
   cd /srv/pihole-whitelist
   ```
2. Оновіть категорії та зовнішні джерела (опційно, але рекомендовано перед першим запуском):
   ```bash
   ./fetch_sources.sh
   ./generate_whitelist.sh --output tmp/initial-whitelist.txt
   ```
3. Переконайтеся, що каталоги для тимчасових файлів існують:
   ```bash
   sudo mkdir -p /var/www/html/admin/tmp/whitelists
   sudo chown www-data:www-data /var/www/html/admin/tmp/whitelists
   sudo mkdir -p /var/log/pihole
   ```

## 3. Запуск Whitelist Builder API

### 3.1 Тимчасовий запуск для тестування

```bash
cd /srv/pihole-whitelist
python3 whitelist_builder_api.py \
  --host 127.0.0.1 \
  --port 5050 \
  --data-dir /var/www/html/admin/tmp/whitelists \
  --log-file /var/log/pihole/whitelist_builder.log \
  --categories-dir /srv/pihole-whitelist/categories
```

Після запуску API доступне за адресами `http://127.0.0.1:5050/health`, `/api/categories`, `/api/build` і `/downloads/<файл>`.
Сервер повторно використовує логіку `build_whitelist.sh` і може працювати без доступу в Інтернет, якщо необхідні категорії
вже в каталозі.

### 3.2 Запуск як сервісу systemd

Створіть юніт `/etc/systemd/system/whitelist-builder.service`:

```ini
[Unit]
Description=Whitelist Builder API для Pi-hole
After=network.target

[Service]
Type=simple
WorkingDirectory=/srv/pihole-whitelist
ExecStart=/usr/bin/python3 /srv/pihole-whitelist/whitelist_builder_api.py \
  --host 127.0.0.1 \
  --port 5050 \
  --data-dir /var/www/html/admin/tmp/whitelists \
  --log-file /var/log/pihole/whitelist_builder.log \
  --categories-dir /srv/pihole-whitelist/categories
Restart=on-failure
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
```

Далі активуйте сервіс:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now whitelist-builder.service
sudo systemctl status whitelist-builder.service
```

У журналі `/var/log/pihole/whitelist_builder.log` відображаються усі звернення до API.

## 4. Налаштування проксі в lighttpd

1. Додайте конфігурацію `/etc/lighttpd/conf-available/15-whitelist-builder.conf`:
   ```conf
   server.modules += ("mod_proxy")

   $HTTP["url"] =~ "^/api/" {
     proxy.server = ("" => (("host" => "127.0.0.1", "port" => 5050)))
   }

   $HTTP["url"] =~ "^/downloads/" {
     proxy.server = ("" => (("host" => "127.0.0.1", "port" => 5050)))
   }
   ```
2. Активуйте модуль і перезапустіть `lighttpd`:
   ```bash
   sudo lighttpd-enable-mod whitelist-builder
   sudo systemctl reload lighttpd
   ```

Після цього Pi-hole проксуватиме запити `/api/*` та `/downloads/*` до бекенда на порту 5050, тому браузеру не потрібні додаткові
налаштування CORS.

## 5. Додавання веб-сторінки до панелі адміністрування

1. Створіть каталог у веб-інтерфейсі Pi-hole:
   ```bash
   sudo mkdir -p /var/www/html/admin/whitelist-builder
   ```
2. Скопіюйте або створіть символічне посилання на сторінку:
   ```bash
   sudo ln -sf /srv/pihole-whitelist/web/whitelist_builder.html \
     /var/www/html/admin/whitelist-builder/index.html
   ```
3. Переконайтеся, що веб-сервер має права читання файлу.

Тепер сторінка доступна за адресою `http://pi.hole/admin/whitelist-builder/` (або `http://<ваш-сервер>/admin/whitelist-builder/`).

## 6. Перевірка роботи

1. Відкрийте сторінку в браузері. У верхній частині має з'явитися кнопка «Оновити категорії» та список чекбоксів.
2. Натисніть «Оновити категорії». Якщо налаштовано вірно, статус покаже кількість категорій.
3. Оберіть кілька категорій, за потреби додайте `extraPaths` та натисніть «Згенерувати whitelist».
4. У відповідь ви побачите кількість доменів та посилання на файл у каталозі `/admin/tmp/whitelists`.
5. Перевірте журнал `/var/log/pihole/whitelist_builder.log` — там повинна з'явитися запис про генерацію.

## 7. Оновлення та обслуговування

- Для отримання останніх змін виконайте `git pull` у `/srv/pihole-whitelist` та перезапустіть сервіс.
- Регулярно запускайте `./fetch_sources.sh` і `./generate_stats_report.sh`, щоб актуалізувати зовнішні списки та статистику.
- Якщо потрібно тимчасово вимкнути API, виконайте `sudo systemctl stop whitelist-builder.service`.

Дотримання цих кроків забезпечить інтеграцію Whitelist Builder у панель Pi-hole згідно з дорожньою картою проєкту.
