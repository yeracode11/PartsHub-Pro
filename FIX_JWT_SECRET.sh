#!/bin/bash

echo "🔧 Проверка и исправление JWT_SECRET на сервере..."

cd /var/www/PartsHub-Pro/autohub-backend

# Проверить текущий JWT_SECRET
echo "📋 Текущий JWT_SECRET в .env:"
cat .env | grep JWT_SECRET || echo "JWT_SECRET не найден в .env"

echo ""
echo "📋 Исправьте JWT_SECRET в .env:"
echo "Откройте файл: nano .env"
echo ""
echo "Найдите или добавьте строку:"
echo "JWT_SECRET=Rtw+Dir1+3+AgjWFCOHJzQJng3FYhWXoNs5HUCkS23Q="
echo ""
echo "После изменения сохраните (Ctrl+X, Y, Enter) и выполните:"
echo "npm run build"
echo "pm2 restart autohub-backend"

