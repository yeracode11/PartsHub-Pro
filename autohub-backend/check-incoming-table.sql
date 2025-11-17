-- Скрипт для проверки существования таблиц incoming_docs и incoming_items
-- Запустите этот скрипт в psql для проверки структуры БД

-- Проверка существования таблицы incoming_docs
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'incoming_docs'
);

-- Проверка существования таблицы incoming_items
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'incoming_items'
);

-- Проверка существования enum типов
SELECT EXISTS (
   SELECT FROM pg_type 
   WHERE typname = 'incoming_doc_status'
);

SELECT EXISTS (
   SELECT FROM pg_type 
   WHERE typname = 'incoming_doc_type'
);

-- Если таблицы не существуют, создайте их через TypeORM синхронизацию
-- или создайте миграцию

