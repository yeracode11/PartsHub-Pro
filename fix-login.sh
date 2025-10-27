#!/bin/bash

echo "🔧 Полная настройка авторизации..."

# Шаг 1: Добавить колонку password
echo "📝 Шаг 1: Добавление колонки password..."
psql -h localhost -U eracode -d autohubdb << EOF1
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "password" character varying(255) NULL;
ALTER TABLE "users" ALTER COLUMN "firebaseUid" DROP NOT NULL;
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "UQ_e621f267079194e5428e19af2f3";
EOF1

# Шаг 2: Создать организацию
echo "📝 Шаг 2: Создание организации..."
psql -h localhost -U eracode -d autohubdb << EOF2
INSERT INTO organizations (
  id, name, "businessType", "isActive", "createdAt", "updatedAt"
)
VALUES (
  '41eb0f1f-332e-4865-a532-a5384d8155c3',
  'Моя Организация',
  'service',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;
EOF2

# Шаг 3: Создать пользователя если его нет
echo "📝 Шаг 3: Создание/обновление пользователя..."
psql -h localhost -U eracode -d autohubdb << EOF3
-- Создать пользователя если его нет
INSERT INTO users (
  id,
  "firebaseUid",
  email,
  password,
  name,
  role,
  "organizationId",
  "isActive",
  "createdAt",
  "updatedAt"
)
SELECT 
  COALESCE(MAX(id), gen_random_uuid()),
  COALESCE(MAX("firebaseUid"), 'test-uid-' || gen_random_uuid()::text),
  'ersul143@gmail.com',
  '$2b$10$r8rsXwuFSUQn82Hq10f7gu.FjD.ISHt.sVE1LEvyBUKGlhxzETCUK',
  COALESCE(MAX(name), 'Test User'),
  COALESCE(MAX(role), 'owner')::text::users_role_enum,
  '41eb0f1f-332e-4865-a532-a5384d8155c3',
  true,
  NOW(),
  NOW()
FROM users
WHERE email = 'ersul143@gmail.com'
ON CONFLICT (email) DO UPDATE
SET 
  password = '$2b$10$r8rsXwuFSUQn82Hq10f7gu.FjD.ISHt.sVE1LEvyBUKGlhxzETCUK',
  "organizationId" = '41eb0f1f-332e-4865-a532-a5384d8155c3',
  "updatedAt" = NOW();
EOF3

echo "✅ Готово! Проверка результатов..."
psql -h localhost -U eracode -d autohubdb -c "
SELECT 
    email,
    name,
    CASE 
        WHEN password IS NULL THEN '❌ Password NOT SET'
        WHEN password = '' THEN '❌ Password EMPTY'
        ELSE '✅ Password SET'
    END as password_status,
    role,
    \"organizationId\",
    \"isActive\"
FROM users
WHERE email = 'ersul143@gmail.com';
"

echo ""
echo "✅ Настройка завершена!"
echo "📧 Email: ersul143@gmail.com"
echo "🔑 Password: admin123"

