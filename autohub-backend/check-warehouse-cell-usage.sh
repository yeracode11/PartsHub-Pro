#!/bin/bash

echo "🔍 Проверка использования warehouseCell в коде..."

echo ""
echo "1. Проверка в исходном коде TypeScript:"
grep -rn "warehouseCell" src/ --include="*.ts" | grep -v "//" | grep -v "migration" | head -20

echo ""
echo "2. Проверка в скомпилированном коде JavaScript:"
if [ -d "dist" ]; then
  grep -rn "warehouseCell" dist/ --include="*.js" | head -20
else
  echo "   ❌ Папка dist/ не найдена. Выполните: npm run build"
fi

echo ""
echo "3. Проверка entity Item:"
grep -A 3 "warehouseCell" src/items/entities/item.entity.ts

echo ""
echo "✅ Проверка завершена"

