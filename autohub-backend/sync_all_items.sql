-- Синхронизировать все существующие товары с quantity > 0 в B2C
UPDATE items SET "syncedToB2C" = true WHERE quantity > 0;

-- Показать результат
SELECT COUNT(*) AS total_items FROM items;
SELECT COUNT(*) AS items_in_stock FROM items WHERE quantity > 0;
SELECT COUNT(*) AS synced_to_b2c FROM items WHERE "syncedToB2C" = true;

