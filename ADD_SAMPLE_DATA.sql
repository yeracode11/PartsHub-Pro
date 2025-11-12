-- SQL скрипт для добавления тестовых товаров в БД

-- Пример товаров для отображения в B2C приложении
-- Замените 'YOUR_ORG_ID' на реальный organizationId

INSERT INTO items (name, sku, category, price, quantity, condition, description, "organizationId", synced, images, "createdAt", "updatedAt")
VALUES 
  ('Фильтр воздушный', 'FILT-001', 'Фильтры', 5000, 50, 'new', 'Оригинальный воздушный фильтр', 'YOUR_ORG_ID', true, '[]', NOW(), NOW()),
  ('Масло моторное 5W-30', 'OIL-001', 'Масла', 12000, 100, 'new', 'Синтетическое моторное масло', 'YOUR_ORG_ID', true, '[]', NOW(), NOW()),
  ('Тормозные колодки', 'BRAKE-001', 'Тормоза', 25000, 30, 'new', 'Передние тормозные колодки', 'YOUR_ORG_ID', true, '[]', NOW(), NOW()),
  ('Свечи зажигания', 'SPARK-001', 'Система зажигания', 8000, 40, 'new', 'Иридиевые свечи зажигания', 'YOUR_ORG_ID', true, '[]', NOW(), NOW()),
  ('Аккумулятор 60Ah', 'BATT-001', 'Электроника', 45000, 20, 'new', 'Автомобильный аккумулятор', 'YOUR_ORG_ID', true, '[]', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Проверка
SELECT COUNT(*) as total_items FROM items WHERE quantity > 0;

