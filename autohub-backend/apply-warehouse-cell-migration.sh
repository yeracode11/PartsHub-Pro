#!/bin/bash

# Скрипт для применения миграции warehouseCell

echo "🔧 Применение миграции для добавления поля warehouseCell..."

# Проверяем, что мы в правильной директории
if [ ! -f "package.json" ]; then
    echo "❌ Ошибка: запустите скрипт из директории autohub-backend"
    exit 1
fi

# Вариант 1: Через TypeORM CLI (если настроен)
if command -v npm &> /dev/null; then
    echo "📦 Применение миграции через TypeORM CLI..."
    npm run typeorm migration:run -d src/data-source.ts
    if [ $? -eq 0 ]; then
        echo "✅ Миграция успешно применена!"
        exit 0
    else
        echo "⚠️ TypeORM CLI не сработал, пробуем SQL напрямую..."
    fi
fi

# Вариант 2: Напрямую через psql
echo "📦 Применение миграции через SQL..."

# Читаем параметры из .env или используем значения по умолчанию
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-eracode}
DB_NAME=${DB_NAME:-autohubdb}

# Запрашиваем пароль, если не задан
if [ -z "$DB_PASSWORD" ]; then
    read -sp "Введите пароль для БД: " DB_PASSWORD
    echo
fi

# Применяем миграцию
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
ALTER TABLE "items" ADD COLUMN IF NOT EXISTS "warehouseCell" character varying(100) NULL;
EOF

if [ $? -eq 0 ]; then
    echo "✅ Миграция успешно применена!"
    echo ""
    echo "📝 Следующие шаги:"
    echo "1. Раскомментируйте поле warehouseCell в src/items/entities/item.entity.ts"
    echo "2. Раскомментируйте код в src/incoming/incoming.service.ts"
    echo "3. Перезапустите сервер: pm2 restart autohub-backend"
else
    echo "❌ Ошибка при применении миграции"
    exit 1
fi

