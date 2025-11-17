-- Исправление enum типов, если они не существуют или неправильные
-- Выполните этот скрипт, если enum типы отсутствуют

-- Создание enum типа для статуса накладной
DO $$ BEGIN
    CREATE TYPE incoming_doc_status AS ENUM ('draft', 'done', 'cancelled');
    RAISE NOTICE 'Enum type incoming_doc_status created';
EXCEPTION
    WHEN duplicate_object THEN 
        RAISE NOTICE 'Enum type incoming_doc_status already exists';
END $$;

-- Создание enum типа для типа накладной
DO $$ BEGIN
    CREATE TYPE incoming_doc_type AS ENUM ('used_parts', 'new_parts', 'own_production');
    RAISE NOTICE 'Enum type incoming_doc_type created';
EXCEPTION
    WHEN duplicate_object THEN 
        RAISE NOTICE 'Enum type incoming_doc_type already exists';
END $$;

-- Проверка значений enum
SELECT 'incoming_doc_status values:' AS info;
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'incoming_doc_status')
ORDER BY enumsortorder;

SELECT 'incoming_doc_type values:' AS info;
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'incoming_doc_type')
ORDER BY enumsortorder;

