#!/bin/bash

# Скрипт для раскомментирования кода warehouseCell после применения миграции

echo "🔧 Раскомментирование кода warehouseCell..."

# Определяем команду sed в зависимости от ОС
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_CMD="sed -i ''"
else
    SED_CMD="sed -i"
fi

# Файл 1: item.entity.ts
echo "📝 Обновление item.entity.ts..."
$SED_CMD 's|// @Column({ type: '\''varchar'\'', length: 100, nullable: true })|@Column({ type: '\''varchar'\'', length: 100, nullable: true })|g' src/items/entities/item.entity.ts
$SED_CMD 's|// warehouseCell: string | null; // Ячейка хранения на складе|warehouseCell: string | null; // Ячейка хранения на складе|g' src/items/entities/item.entity.ts
$SED_CMD '/Временно закомментировано, пока поле не добавлено в БД через миграцию/d' src/items/entities/item.entity.ts

# Файл 2: incoming.service.ts
echo "📝 Обновление incoming.service.ts..."
$SED_CMD 's|// if (incomingItem.warehouseCell) {|if (incomingItem.warehouseCell) {|g' src/incoming/incoming.service.ts
$SED_CMD 's|//   item.warehouseCell = incomingItem.warehouseCell;|  item.warehouseCell = incomingItem.warehouseCell;|g' src/incoming/incoming.service.ts
$SED_CMD 's|// }|}|g' src/incoming/incoming.service.ts
$SED_CMD 's|// newItem.warehouseCell = incomingItem.warehouseCell || null;|newItem.warehouseCell = incomingItem.warehouseCell || null;|g' src/incoming/incoming.service.ts
$SED_CMD '/Временно отключено - поле warehouseCell еще не добавлено в БД/d' src/incoming/incoming.service.ts

echo "✅ Код раскомментирован!"
echo ""
echo "📝 Следующий шаг:"
echo "pm2 restart autohub-backend"

