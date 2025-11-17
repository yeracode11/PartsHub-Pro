#!/bin/bash

# Скрипт для проверки, что код incoming обновлен на сервере

echo "🔍 Проверка кода incoming.service.ts..."

cd /var/www/PartsHub-Pro/autohub-backend

# Проверяем, что используется прямой SQL запрос
if grep -q "queryRunner.query" src/incoming/incoming.service.ts; then
    echo "✅ Прямой SQL запрос найден в исходном коде"
else
    echo "❌ Прямой SQL запрос НЕ найден - код не обновлен!"
    exit 1
fi

# Проверяем, что используется queryRunner.query, а не QueryBuilder.insert
if grep -q "INSERT INTO \"incoming_docs\"" src/incoming/incoming.service.ts; then
    echo "✅ Прямой SQL INSERT найден в исходном коде"
else
    echo "❌ Прямой SQL INSERT НЕ найден - код не обновлен!"
    exit 1
fi

# Проверяем скомпилированный код
if grep -q "queryRunner.query" dist/incoming/incoming.service.js 2>/dev/null; then
    echo "✅ Прямой SQL запрос найден в скомпилированном коде"
else
    echo "⚠️  Прямой SQL запрос НЕ найден в скомпилированном коде - нужна пересборка!"
    echo "   Запустите: npm run build"
    exit 1
fi

echo ""
echo "✅ Код обновлен правильно!"
echo ""
echo "Если ошибка все еще возникает, проверьте логи:"
echo "   pm2 logs autohub-backend --lines 100 | grep -E 'IncomingController|IncomingService|createdById'"

