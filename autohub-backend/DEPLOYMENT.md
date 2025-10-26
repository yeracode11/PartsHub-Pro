# Инструкция по деплою AutoHub Backend

## Предварительные требования

1. PostgreSQL база данных (можно использовать бесплатные варианты):
   - [ElephantSQL](https://www.elephantsql.com/) - бесплатный план включает 20MB
   - [Neon](https://neon.tech/) - serverless PostgreSQL
   - [Supabase](https://supabase.com/) - включает PostgreSQL
   - [AWS RDS](https://aws.amazon.com/rds/) - для серьезных проектов

2. Аккаунт на хостинге (выберите один):
   - **Heroku** (рекомендуется для начала) - бесплатный план
   - **Railway** - бесплатный план
   - **Render** - бесплатный план
   - **Fly.io** - бесплатный план

## Настройка PostgreSQL

1. Создайте базу данных на выбранном провайдере
2. Получите connection string (будет выглядеть как `postgresql://user:password@host:5432/database`)

## Деплой на Heroku

### 1. Установите Heroku CLI

```bash
# macOS
brew install heroku/brew/heroku

# Linux
curl https://cli-assets.heroku.com/install.sh | sh
```

### 2. Логин в Heroku

```bash
heroku login
```

### 3. Создайте приложение

```bash
cd autohub-backend
heroku create autohub-backend-prod
```

### 4. Добавьте PostgreSQL addon

```bash
heroku addons:create heroku-postgresql:mini
```

### 5. Настройте переменные окружения

```bash
heroku config:set NODE_ENV=production
heroku config:set DB_PASSWORD=your_password
heroku config:set JWT_SECRET=your_secret_key
heroku config:set CORS_ORIGIN=https://your-frontend-domain.com
```

### 6. Деплой кода

```bash
git push heroku main
```

### 7. Проверьте логи

```bash
heroku logs --tail
```

## Деплой на Railway

### 1. Установите Railway CLI

```bash
npm install -g @railway/cli
```

### 2. Логин

```bash
railway login
```

### 3. Инициализируйте проект

```bash
cd autohub-backend
railway init
```

### 4. Создайте PostgreSQL базу

```bash
railway add postgres
```

### 5. Деплой

```bash
railway up
```

## Деплой на Render

### 1. Создайте аккаунт на [render.com](https://render.com)

### 2. Подключите GitHub репозиторий

### 3. Создайте Web Service

- Build Command: `npm run build`
- Start Command: `npm run start:prod`
- Environment: `Node`

### 4. Добавьте PostgreSQL базу данных

- Создайте PostgreSQL database
- Скопируйте connection string

### 5. Настройте переменные окружения

```
NODE_ENV=production
DATABASE_URL=<your-postgres-connection-string>
JWT_SECRET=<your-secret>
CORS_ORIGIN=<your-frontend-url>
```

## Настройка CORS

После деплоя бэкенда, обновите CORS настройки в `src/main.ts`:

```typescript
app.enableCors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
  credentials: true,
});
```

## Проверка работы

После деплоя проверьте:

```bash
curl https://your-backend-url.com/api
```

Должен вернуться `Hello World!`

## Мониторинг

- **Heroku**: `heroku logs --tail`
- **Railway**: `railway logs`
- **Render**: используйте dashboard на сайте

## Обновление кода

```bash
git push heroku main
# или
railway up
```

## Откат изменений

Если что-то пошло не так:

```bash
heroku rollback
```

