# nginx для лендинга vinly.darasoft.kz

Конфиг проксирует домен на контейнер `autohub-landing` (порт `LANDING_PORT` на хосте, по умолчанию 3003; на этом сервере 3003 занят, используется 3010).
Файл: `vinly.darasoft.kz.conf`. Выполняется на сервере (Ubuntu, nginx 1.24).

## 1. Запустить лендинг

В `.env` рядом с `docker-compose.yml`:

```
LANDING_SITE_URL=https://vinly.darasoft.kz
LANDING_PORT=3010
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
```

```
docker compose up -d --build landing
curl -sI http://127.0.0.1:3010/ | head -1     # ожидается HTTP/1.1 200 OK
```

`LANDING_SITE_URL` попадает в сборку, поэтому при смене нужна пересборка. Пока он не задан, сайт закрыт от индексации.

## 2. Сертификат

DNS уже указывает на сервер (A-запись `vinly.darasoft.kz` → `108.174.78.106`). Сертификат выпускается через стандартный
хост nginx, который отдаёт `/var/www/html`, без остановки nginx и до установки этого конфига:

```
sudo certbot certonly --webroot -w /var/www/html -d vinly.darasoft.kz
```

Если certbot не установлен: `sudo apt install certbot`.

## 3. Установить конфиг

```
sudo cp deploy/nginx/vinly.darasoft.kz.conf /etc/nginx/sites-available/vinly.darasoft.kz
sudo ln -s /etc/nginx/sites-available/vinly.darasoft.kz /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Если `nginx -t` ругается на `vinly_ssl` или `http2`, проверьте, что другие хосты не объявляют зону с тем же именем.

## 4. Проверка

```
curl -sI https://vinly.darasoft.kz/ | head -1       # HTTP/2 200
curl -sI http://vinly.darasoft.kz/  | head -3       # 301 на https
```

Автопродление сертификата ставит пакет certbot (таймер `certbot.timer`). Проверить: `sudo certbot renew --dry-run`.
