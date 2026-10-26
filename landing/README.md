# Vinly Business — лендинг

Продающая страница для владельцев авторазборок, СТО и магазинов запчастей в Казахстане.
Цель — заявки на демонстрацию. Next.js 16 (App Router), TypeScript, обычный CSS, шрифты Unbounded (заголовки) и Manrope (текст) через next/font/google, самохостятся при сборке.

## Запуск

```bash
cd landing
npm install
npm run dev        # http://localhost:3000
npm run build && npm start
npm run lint       # проверка типов (tsc --noEmit)
```

## Структура

```
landing/
  src/
    app/
      layout.tsx          # шрифт, метаданные, lang="ru"
      page.tsx            # сборка секций
      globals.css         # токены (из AppTheme) и все стили
      api/lead/route.ts   # приём заявок (см. ниже)
      icon.svg, robots.ts
    components/           # Header, PhoneFrame, LeadForm, StickyCta
    content/site.ts       # ВЕСЬ текст страницы — правьте здесь
  public/
    screens/*.webp        # скриншоты приложения
    privacy-policy.html   # копия политики приложения (см. «Перед запуском»)
  scripts/optimize-screens.mjs   # PNG → WebP для public/screens
```

## Заявки

`POST /api/lead` валидирует форму и доставляет заявку каналами (можно оба сразу):

- **Telegram-бот**: в @BotFather выполните `/newbot` и скопируйте токен в `TELEGRAM_BOT_TOKEN`; напишите боту любое сообщение (для группы добавьте бота в неё) и возьмите `chat.id` из `https://api.telegram.org/bot<токен>/getUpdates` в `TELEGRAM_CHAT_ID`. Токен — секрет: в репозиторий и в чаты не попадает.
- **Вебхук** `LEAD_WEBHOOK_URL`: POST JSON `{ name, phone, city, businessType, comment, receivedAt, source }` (CRM, Make/Zapier; необязательно).

Заявка считается принятой, если сработал хотя бы один настроенный канал; иначе форма показывает ошибку (502). Если не настроен ни один канал: в разработке — заглушка (в лог строка без имени, телефон замаскирован), в production — ответ 503, чтобы заявки не терялись молча. 

## Скриншоты

Все кадры сняты в приложении на демо-данных (вымышленные клиенты и номера, локальная база, не боевая), статус-бар симулятора выставлен на 9:41.
Обновить кадры: снять PNG 1320×2868 и выполнить

```bash
node scripts/optimize-screens.mjs <папка-с-png>
```

Имена файлов — как в `src/content/site.ts` (`parts-warehouse`, `sto-schedule` и т. д.).

## Перед запуском

- Политика в `public/privacy-policy.html` написана под сайт (оператор ИП «ERASOFT», как в приложении; данные формы, Telegram, отсутствие cookie и аналитики). Это черновик, а не юридическая консультация: срок хранения заявок не задан, формулировки нужно проверить с юристом.
- Домен: задайте `NEXT_PUBLIC_SITE_URL` (например `https://example.kz`) и пересоберите сайт. **Пока он не задан, индексация закрыта**: `robots.txt` отдаёт `Disallow: /`, на странице `noindex`, sitemap пустой. С доменом открываются `robots.txt` (закрыт только `/api/`), `sitemap.xml`, canonical, `index, follow`.
- SEO: title/description, Open Graph и Twitter-карточка, canonical, JSON-LD (`SoftwareApplication` и `FAQPage` из `src/content/site.ts`, без цен и рейтингов), `opengraph-image.png`/`twitter-image.png` (1200×630, сделаны вручную: при смене текста перегенерируйте), `apple-icon.png`. После запуска добавьте сайт в Google Search Console и Яндекс Вебмастер и отправьте sitemap.
- Аналитика и пиксели не подключены.
- Шрифты: Unbounded + Manrope через `next/font/google` (нужен доступ в сеть при сборке); замена — в `src/app/layout.tsx` и переменных `--font-display` / `--font-sans` в `globals.css`.
- Название «Vinly Business» и логотип (знак «дорога-V» из `LOGO.svg`) теперь и в приложении, и на сайте (`public/logo.svg`, `src/app/icon.svg`).
- Широкие кадры `public/screens/desktop-*.webp` сняты в macOS-версии приложения (release-сборка, демо-база), с обрезанным заголовком окна.

## Правила контента

Только то, что реализовано в приложении. Цен, цифр экономии, числа клиентов, отзывов и интеграций на странице нет — не добавляйте их без подтверждения.

## Деплой на VPS (вместе с бэкендом)

Сайт добавлен сервисом `landing` в корневой `docker-compose.yml` (порт `LANDING_PORT`, по умолчанию 3003; контейнер `autohub-landing`). Отдельного `.env` в `landing/` не нужно: значения подставляются из `.env` рядом с `docker-compose.yml` на сервере, как у бэкенда (`JWT_SECRET`, пароль БД).

В серверный `.env` добавьте строки (значений в репозитории нет):

```
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
LANDING_SITE_URL=https://ваш-домен   # без него сайт закрыт от индексации
```

Запуск: `docker compose up -d --build landing`. Домен и HTTPS нужно направить на порт сайта через ваш обратный прокси; в репозитории конфигурации прокси нет. `LANDING_SITE_URL` попадает в сборку, поэтому после смены нужна пересборка.
