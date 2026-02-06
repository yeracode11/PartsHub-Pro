#!/bin/bash

# Скрипт для вывода списка пользователей из локальной PostgreSQL
# Использование: bash list-users-local.sh

echo "🔍 Поиск способа подключения к PostgreSQL..."

# Вариант 1: Через sudo от имени postgres
echo "Попытка 1: Через sudo -u postgres"
sudo -u postgres psql -d autohubdb -c "
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

# Вариант 2: Через postgres пользователя напрямую
echo "Попытка 2: Через пользователя postgres"
psql -U postgres -d autohubdb -c "
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

# Вариант 3: Через localhost с паролем
echo "Попытка 3: Через localhost"
PGPASSWORD=$(grep DB_PASSWORD .env 2>/dev/null | cut -d '=' -f2 | tr -d '"' | tr -d "'") psql -h localhost -U postgres -d autohubdb -c "
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

# Вариант 4: Пробуем найти правильную БД
echo "Попытка 4: Поиск базы данных..."
sudo -u postgres psql -c "\l" | grep -E "autohub|eracode" || psql -U postgres -c "\l" | grep -E "autohub|eracode"

echo ""
echo "❌ Не удалось подключиться автоматически."
echo ""
echo "Попробуйте вручную один из вариантов:"
echo ""
echo "1. Через sudo:"
echo "   sudo -u postgres psql -d autohubdb"
echo ""
echo "2. Через postgres пользователя:"
echo "   psql -U postgres -d autohubdb"
echo ""
echo "3. С паролем из .env:"
echo "   PGPASSWORD=\$(grep DB_PASSWORD .env | cut -d '=' -f2) psql -h localhost -U postgres -d autohubdb"
echo ""
echo "4. Проверить список баз данных:"
echo "   sudo -u postgres psql -c '\\l'"
