# whatsapp-gateway

Свой аналог Green API для Vinly Business. У каждого магазина свой «инстанс»: номер подключается
по QR в «Связанных устройствах», как WhatsApp Web. Шлюз держит сессии, принимает входящие и
отправляет исходящие. Вся бизнес-логика (чаты, бот, права) — в `autohub-backend`.

Под капотом библиотека [Baileys](https://github.com/WhiskeySockets/Baileys) (неофициальный протокол WhatsApp Web).

## Риски

Это неофициальный способ, как и сам Green API. WhatsApp может заблокировать номер магазина,
особенно новый номер или номер, который пишет незнакомым людям. Поэтому:

- номер Vinly, подтверждённый в Meta, сюда **не подключаем** — он остаётся на официальном API;
- исходящие идут по одному, с паузой 3–5 с, «печатает…» перед отправкой;
- лимиты на номер: 12 в минуту, 500 в сутки, 30 новых собеседников в сутки (кому раньше не писали);
- перед первым сообщением новому номеру проверяем, что он есть в WhatsApp.

Лимиты меняются переменными окружения (ниже).

## Как устроено

```
Магазин (Flutter) ──JWT──▶ backend /api/whatsapp/web/* ──x-api-key──▶ gateway /instances/:orgId/*
                                    ▲                                         │
                                    └──── /webhooks/wa-gateway (HMAC) ◀───────┘ входящие, смена статуса
```

- id инстанса = `organizationId` магазина; сессия хранится в `SESSIONS_DIR/<organizationId>/`
  (docker volume `whatsapp_sessions`). Без volume после пересборки все магазины отвяжутся.
- после перезапуска шлюз сам поднимает все сохранённые сессии;
- если магазин отвязал устройство в телефоне или номер заблокирован, сессия удаляется,
  в приложении статус «Не подключён» с причиной;
- группы, статусы и каналы игнорируются, только личные чаты.

## API (только для backend, заголовок `x-api-key`)

| Метод | Путь | Что делает |
|---|---|---|
| POST | `/instances/:id/start` | запустить, вернуть статус и QR (`qrDataUrl`, PNG data URL) |
| GET | `/instances/:id` | статус: `starting`, `qr`, `authorized`, `reconnecting`, `logged_out`, `stopped` |
| POST | `/instances/:id/logout` | отвязать устройство и удалить сессию |
| POST | `/instances/:id/send-text` | `{ phone, text }` |
| POST | `/instances/:id/send-file` | `{ phone, url, fileName?, mimetype?, caption? }` |
| GET | `/health` | без ключа |

Ошибки: `409 not_connected`, `422 not_on_whatsapp`, `429 per_day | new_chats_per_day`.

Вебхук в backend: `POST BACKEND_WEBHOOK_URL`, тело JSON, подпись `x-vinly-signature: sha256=<HMAC тела>`.
События `{"type":"state",...}` и `{"type":"message","phone","fromMe","text","messageType",...}`.

## Переменные окружения

| Переменная | По умолчанию | |
|---|---|---|
| `GATEWAY_API_KEY` | — (обязательно) | = `WA_GATEWAY_API_KEY` у backend |
| `GATEWAY_WEBHOOK_SECRET` | — | = `WA_GATEWAY_WEBHOOK_SECRET` у backend |
| `BACKEND_WEBHOOK_URL` | — | `http://backend:3000/webhooks/wa-gateway` |
| `SESSIONS_DIR` | `./sessions` | в Docker `/app/sessions` |
| `SEND_MIN_DELAY_MS` / `SEND_JITTER_MS` | 3000 / 2000 | пауза между исходящими |
| `SEND_MAX_PER_MINUTE` | 12 | |
| `SEND_MAX_PER_DAY` | 500 | |
| `SEND_MAX_NEW_CHATS_PER_DAY` | 30 | |

## Запуск на сервере

1. В `.env` рядом с `docker-compose.yml` добавить два случайных секрета:
   ```
   WA_GATEWAY_API_KEY=<openssl rand -hex 32>
   WA_GATEWAY_WEBHOOK_SECRET=<openssl rand -hex 32>
   ```
2. `docker compose up -d --build whatsapp-gateway backend`
3. Применить миграцию backend: `npm run migration:run` (таблица `whatsapp_web_instances`).
4. В приложении: WhatsApp → «Подключить по QR».

## Разработка

```
npm install
npm test        # сборка + node:test
GATEWAY_API_KEY=dev BACKEND_WEBHOOK_URL=http://localhost:3002/webhooks/wa-gateway \
GATEWAY_WEBHOOK_SECRET=dev npm run build && npm start
```
