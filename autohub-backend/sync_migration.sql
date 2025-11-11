-- Миграция для синхронизации B2C ↔ B2B
-- Применение: PGPASSWORD=erasoft123 psql -U eracode -d autohubdb -h localhost -f sync_migration.sql

-- Добавляем флаг isB2C в таблицу orders (заказы из B2C магазина)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS "isB2C" BOOLEAN DEFAULT false;

-- Добавляем флаг syncedToB2C в таблицу items (товары синхронизированные в B2C)
ALTER TABLE items ADD COLUMN IF NOT EXISTS "syncedToB2C" BOOLEAN DEFAULT false;

-- Создаем индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_orders_is_b2c ON orders("isB2C");
CREATE INDEX IF NOT EXISTS idx_items_synced_b2c ON items("syncedToB2C");

-- Вывод результатов
SELECT 'Migration completed successfully!' AS status;
SELECT COUNT(*) AS total_orders FROM orders;
SELECT COUNT(*) AS total_items FROM items;
SELECT COUNT(*) AS b2c_orders FROM orders WHERE "isB2C" = true;
SELECT COUNT(*) AS synced_items FROM items WHERE "syncedToB2C" = true;
