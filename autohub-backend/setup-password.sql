-- Создать тестового пользователя с паролем admin123
-- Хеш был сгенерирован командой: node -e "const bcrypt=require('bcrypt');bcrypt.hash('admin123',10).then(h=>console.log(h))"

-- Обновляем существующего пользователя или создаем нового
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
VALUES (
  gen_random_uuid(),
  'test-uid-' || gen_random_uuid()::text,
  'ersul143@gmail.com',
  '$2b$10$r8rsXwuFSUQn82Hq10f7gu.FjD.ISHt.sVE1LEvyBUKGlhxzETCUK', -- хеш для admin123
  'Test User',
  'owner',
  '41eb0f1f-332e-4865-a532-a5384d8155c3',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (email) DO UPDATE
SET 
  password = EXCLUDED.password,
  "updatedAt" = NOW();

-- Создаем организацию если её нет
INSERT INTO organizations (
  id,
  name,
  "businessType",
  "isActive",
  "createdAt",
  "updatedAt"
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

