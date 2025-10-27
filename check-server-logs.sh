#!/bin/bash

echo "📋 Проверка логов сервера..."
echo ""

echo "🔍 Показываю последние логи входа:"
pm2 logs autohub-backend --lines 100 | grep -E "(AuthController|JWT|login|password|Secret)" || echo "Логи не найдены"

echo ""
echo "🔄 Проверяю JWT_SECRET:"
cd /var/www/PartsHub-Pro/autohub-backend
cat .env | grep JWT_SECRET

echo ""
echo "📊 Статус бэкенда:"
pm2 status

echo ""
echo "💡 Чтобы смотреть логи в реальном времени:"
echo "   pm2 logs autohub-backend --lines 0"

