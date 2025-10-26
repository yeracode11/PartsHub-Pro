# Деплой AutoHub Backend на VPS

## Предварительные требования

1. VPS с Ubuntu 20.04+ или 22.04+
2. SSH доступ к серверу
3. Минимум 1GB RAM, 10GB диска

## Настройка сервера

### 1. Подключитесь к серверу

```bash
ssh root@your-server-ip
```

### 2. Обновите систему

```bash
apt update && apt upgrade -y
```

### 3. Установите необходимые пакеты

```bash
# Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# PostgreSQL
apt install -y postgresql postgresql-contrib

# Nginx (для reverse proxy)
apt install -y nginx

# PM2 (для управления Node.js процессами)
npm install -g pm2

# Git
apt install -y git
```

### 4. Создайте пользователя для приложения

```bash
adduser autohub
usermod -aG sudo autohub
su - autohub
```

### 5. Настройте PostgreSQL

```bash
sudo -u postgres psql

# В PostgreSQL консоли:
CREATE DATABASE autohub;
CREATE USER autohub_user WITH PASSWORD 'your_strong_password';
GRANT ALL PRIVILEGES ON DATABASE autohub TO autohub_user;
\q
```

### 6. Настройте Node.js базу для PM2

```bash
pm2 startup
# Скопируйте и выполните команду, которую показал PM2
```

## Клонирование и настройка проекта

### 1. Клонируйте репозиторий

```bash
cd /home/autohub
git clone https://github.com/yeracode11/PartsHub-Pro.git
cd PartsHub-Pro/autohub-backend
```

### 2. Установите зависимости

```bash
npm install
```

### 3. Настройте переменные окружения

```bash
nano .env
```

Содержимое `.env`:

```env
# Node environment
NODE_ENV=production
PORT=3000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=autohub_user
DB_PASSWORD=your_strong_password
DB_NAME=autohub

# JWT
JWT_SECRET=your_super_secret_jwt_key_change_this_in_production

# CORS
CORS_ORIGIN=https://your-domain.com

# Upload directory
UPLOAD_DIR=./uploads
```

### 4. Создайте директорию для загрузок

```bash
mkdir -p uploads/items
chmod 755 uploads/items
```

### 5. Соберите проект

```bash
npm run build
```

### 6. Запустите с PM2

```bash
pm2 start npm --name "autohub-backend" -- run start:prod
pm2 save
```

Проверьте статус:

```bash
pm2 status
pm2 logs autohub-backend
```

## Настройка Nginx

### 1. Создайте конфигурацию

```bash
sudo nano /etc/nginx/sites-available/autohub-backend
```

Содержимое:

```nginx
upstream autohub_backend {
    server localhost:3000;
}

server {
    listen 80;
    server_name your-domain.com;

    client_max_body_size 10M;

    # API
    location /api {
        proxy_pass http://autohub_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files (uploads)
    location /uploads {
        alias /home/autohub/PartsHub-Pro/autohub-backend/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location / {
        proxy_pass http://autohub_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### 2. Активируйте конфигурацию

```bash
sudo ln -s /etc/nginx/sites-available/autohub-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Настройка SSL (HTTPS)

### 1. Установите Certbot

```bash
sudo apt install certbot python3-certbot-nginx
```

### 2. Получите сертификат

```bash
sudo certbot --nginx -d your-domain.com
```

## Управление приложением

### Просмотр логов

```bash
pm2 logs autohub-backend
pm2 logs autohub-backend --lines 100
```

### Перезапуск

```bash
pm2 restart autohub-backend
```

### Обновление кода

```bash
cd /home/autohub/PartsHub-Pro/autohub-backend
git pull origin main
npm install
npm run build
pm2 restart autohub-backend
```

### Остановка

```bash
pm2 stop autohub-backend
```

### Удаление

```bash
pm2 delete autohub-backend
```

## Бэкап базы данных

### Создание бэкапа

```bash
#!/bin/bash
BACKUP_DIR="/home/autohub/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

pg_dump -U autohub_user -d autohub > $BACKUP_DIR/autohub_$DATE.sql
```

### Добавьте в cron для автоматических бэкапов

```bash
crontab -e

# Добавьте строку (бэкап каждый день в 2:00)
0 2 * * * /home/autohub/backup.sh
```

## Мониторинг

### PM2 мониторинг

```bash
pm2 monit
```

### Система

```bash
# Память
free -h

# Диск
df -h

# Процессы
htop
```

## Настройка firewall

```bash
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
```

## Часто используемые команды

```bash
# Статус сервисов
sudo systemctl status nginx
sudo systemctl status postgresql
pm2 status

# Логи
sudo journalctl -u nginx
sudo journalctl -u postgresql
pm2 logs

# Диск
du -sh /home/autohub/PartsHub-Pro
```

## Проверка работы

```bash
# Локально
curl http://localhost:3000

# Через Nginx
curl http://your-domain.com

# API
curl http://your-domain.com/api
```

## Troubleshooting

### Если приложение не запускается

```bash
pm2 logs autohub-backend --err
```

### Если не работает база данных

```bash
sudo systemctl status postgresql
sudo -u postgres psql -d autohub
```

### Если Nginx не работает

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

