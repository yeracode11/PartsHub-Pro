#!/bin/bash

echo "🔍 Диагностика JWT проблемы..."

# Шаг 1: Проверить .env
echo "📋 Проверка .env файла:"
cd /var/www/PartsHub-Pro/autohub-backend
if [ -f ".env" ]; then
    echo "✅ .env существует"
    cat .env | grep JWT_SECRET || echo "❌ JWT_SECRET не найден в .env"
else
    echo "❌ .env файл отсутствует"
fi

echo ""

# Шаг 2: Проверить переменную окружения
echo "📋 Переменная окружения:"
echo "JWT_SECRET=$JWT_SECRET"
if [ -z "$JWT_SECRET" ]; then
    echo "❌ Переменная окружения JWT_SECRET не установлена"
else
    echo "✅ Переменная окружения JWT_SECRET установлена"
fi

echo ""

# Шаг 3: Проверить логи бэкенда
echo "📋 Последние логи JWT:"
pm2 logs autohub-backend --lines 100 | grep -E "(JWT|🔐)" | tail -10 || echo "Логи JWT не найдены"

echo ""

# Шаг 4: Проверить статус бэкенда
echo "📋 Статус бэкенда:"
pm2 status | grep autohub-backend

echo ""
echo "💡 Рекомендации:"
echo "1. Убедитесь что JWT_SECRET в .env: Rtw+Dir1+3+AgjWFCOHJzQJng3FYhWXoNs5HUCkS23Q="
echo "2. Перезапустите бэкенд: pm2 restart autohub-backend"
echo "3. В приложении войдите заново (старый токен очистится)"
echo "4. Проверьте логи снова"

echo ""
echo "🔧 Быстрое исправление:"
echo "cd /var/www/PartsHub-Pro && git pull origin main && chmod +x UPDATE_ENV.sh && ./UPDATE_ENV.sh && cd autohub-backend && pm2 restart autohub-backend"

