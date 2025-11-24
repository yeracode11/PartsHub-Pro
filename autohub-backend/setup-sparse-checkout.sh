#!/bin/bash

# Скрипт для настройки sparse-checkout на сервере
# Использование: запустите на сервере в папке проекта

set -e

echo "🔧 Настройка sparse-checkout для загрузки только папки autohub-backend..."

# Проверяем, что мы в git репозитории
if [ ! -d ".git" ]; then
    echo "❌ Ошибка: это не git репозиторий!"
    exit 1
fi

# Включаем sparse-checkout
git config core.sparseCheckout true

# Указываем, какие папки нужно загружать
echo "autohub-backend/*" > .git/info/sparse-checkout
echo "Stack.md" >> .git/info/sparse-checkout
echo "VEHICLES_MODULE.md" >> .git/info/sparse-checkout
echo "WHATSAPP_SETUP.md" >> .git/info/sparse-checkout

# Применяем изменения
git read-tree -mu HEAD

echo "✅ Настройка завершена!"
echo ""
echo "Теперь при git pull будут загружаться только:"
echo "  - autohub-backend/"
echo "  - Stack.md, VEHICLES_MODULE.md, WHATSAPP_SETUP.md"
echo ""
echo "Для применения изменений выполните:"
echo "  git pull"

