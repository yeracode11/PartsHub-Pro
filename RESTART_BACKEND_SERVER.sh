#!/bin/bash

echo "🔍 Проверка статуса backend сервера..."
echo ""

# Переходим в директорию backend
cd /var/www/PartsHub-Pro/autohub-backend || exit 1

# Проверяем статус PM2
echo "📊 Статус PM2:"
pm2 status

echo ""
echo "🔍 Проверяем, запущен ли autohub-backend:"
if pm2 list | grep -q "autohub-backend"; then
    echo "✅ autohub-backend найден в PM2"
    echo ""
    echo "🔄 Перезапускаем backend..."
    pm2 restart autohub-backend
else
    echo "❌ autohub-backend не найден в PM2"
    echo ""
    echo "🚀 Запускаем backend..."
    
    # Проверяем, что dist папка существует
    if [ ! -d "dist" ]; then
        echo "📦 Собираем проект..."
        npm run build
    fi
    
    # Запускаем через PM2
    pm2 start dist/main.js --name autohub-backend
    pm2 save
fi

echo ""
echo "⏳ Ждем 3 секунды..."
sleep 3

echo ""
echo "📊 Финальный статус:"
pm2 status

echo ""
echo "📋 Последние логи:"
pm2 logs autohub-backend --lines 20 --nostream

echo ""
echo "✅ Готово! Backend должен быть доступен на http://78.140.246.83:3000"
echo ""
echo "💡 Для просмотра логов в реальном времени:"
echo "   pm2 logs autohub-backend --lines 0"

