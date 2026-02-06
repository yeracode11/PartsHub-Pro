#!/bin/bash

# Скрипт для вывода списка пользователей через Docker
# Использование: bash list-users-docker.sh

echo "🔍 Поиск контейнера PostgreSQL..."
CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "postgres|autohub" | head -1)

if [ -z "$CONTAINER" ]; then
    echo "❌ Контейнер PostgreSQL не найден"
    echo "Запущенные контейнеры:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

echo "✅ Найден контейнер: $CONTAINER"
echo ""

# Пробуем разные варианты подключения
echo "📋 Список пользователей:"
echo ""

# Вариант 1: autohub_user / autohub
docker exec -it "$CONTAINER" psql -U autohub_user -d autohub -c "
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.\"isActive\",
  o.name as \"organizationName\",
  u.\"createdAt\"
FROM users u
LEFT JOIN organizations o ON u.\"organizationId\" = o.id
ORDER BY u.\"createdAt\" DESC;
" 2>/dev/null && exit 0

# Вариант 2: postgres / postgres
docker exec -it "$CONTAINER" psql -U postgres -d postgres -c "
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.\"isActive\",
  o.name as \"organizationName\",
  u.\"createdAt\"
FROM users u
LEFT JOIN organizations o ON u.\"organizationId\" = o.id
ORDER BY u.\"createdAt\" DESC;
" 2>/dev/null && exit 0

# Вариант 3: Пробуем найти правильную БД
echo "🔍 Поиск базы данных..."
docker exec -it "$CONTAINER" psql -U postgres -c "\l" | grep -E "autohub|eracode"

echo ""
echo "❌ Не удалось подключиться. Попробуйте вручную:"
echo "   docker exec -it $CONTAINER psql -U <user> -d <database>"
echo ""
echo "Или проверьте настройки в docker-compose.yml"
