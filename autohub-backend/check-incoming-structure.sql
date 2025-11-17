-- Проверка структуры таблиц и enum типов
-- Выполните эти команды в psql

-- 1. Проверка enum типов
SELECT typname, typtype 
FROM pg_type 
WHERE typname IN ('incoming_doc_status', 'incoming_doc_type');

-- 2. Проверка структуры таблицы incoming_docs
\d incoming_docs

-- 3. Проверка структуры таблицы incoming_items
\d incoming_items

-- 4. Проверка значений enum типов
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'incoming_doc_status')
ORDER BY enumsortorder;

SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'incoming_doc_type')
ORDER BY enumsortorder;

-- 5. Проверка ограничений (constraints)
SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'incoming_docs'::regclass;

-- 6. Проверка индексов
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('incoming_docs', 'incoming_items');

