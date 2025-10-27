#!/bin/bash

echo "🔍 Диагностика пользователя..."

psql -h localhost -U eracode -d autohubdb << EOF
-- Проверить что колонка password существует
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users' 
  AND column_name = 'password';

-- Проверить пользователя
SELECT 
    id,
    email,
    name,
    "firebaseUid",
    "organizationId",
    role,
    "isActive",
    CASE 
        WHEN password IS NULL THEN '❌ NULL'
        WHEN password = '' THEN '❌ EMPTY'
        ELSE '✅ ' || substring(password, 1, 30) || '...'
    END as password_status,
    "createdAt",
    "updatedAt"
FROM users
WHERE email = 'ersul143@gmail.com';
EOF

