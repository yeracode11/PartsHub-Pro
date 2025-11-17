#!/bin/bash

# Скрипт для выполнения SQL команд на сервере
# Использование: ./run-incoming-sql.sh

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Проверка и создание таблиц incoming_docs и incoming_items${NC}"
echo ""

# Проверяем, есть ли переменная DATABASE_URL в .env
if [ -f .env ]; then
    source .env
    echo -e "${GREEN}✓ Найден файл .env${NC}"
    
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}✗ DATABASE_URL не найден в .env${NC}"
        echo "Проверьте файл .env и убедитесь, что DATABASE_URL установлен"
        exit 1
    fi
    
    echo -e "${GREEN}✓ DATABASE_URL найден${NC}"
    echo ""
    
    # Парсим DATABASE_URL
    # Формат: postgresql://user:password@host:port/database
    DB_USER=$(echo $DATABASE_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASS=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    echo "Параметры подключения:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo ""
    
    # Устанавливаем переменную окружения для пароля
    export PGPASSWORD=$DB_PASS
    
    # Выполняем SQL скрипт
    echo -e "${YELLOW}Выполнение SQL скрипта...${NC}"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f create-incoming-tables.sql
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Таблицы успешно созданы/проверены${NC}"
    else
        echo ""
        echo -e "${RED}✗ Ошибка при выполнении SQL скрипта${NC}"
        exit 1
    fi
    
    # Очищаем пароль из переменной окружения
    unset PGPASSWORD
    
else
    echo -e "${RED}✗ Файл .env не найден${NC}"
    echo ""
    echo "Альтернативный способ - подключитесь вручную:"
    echo ""
    echo "1. Если знаете параметры БД:"
    echo "   psql -h localhost -U postgres -d your_database -f create-incoming-tables.sql"
    echo ""
    echo "2. Или подключитесь интерактивно:"
    echo "   psql -h localhost -U postgres -d your_database"
    echo "   Затем выполните команды из create-incoming-tables.sql"
    echo ""
    exit 1
fi

