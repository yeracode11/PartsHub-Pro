-- Создание тестовых данных для AutoHub

-- 1. Создаем организацию
INSERT INTO organizations (id, name, "businessType", "isActive", "phone", "address", "createdAt", "updatedAt")
VALUES (
  '41eb0f1f-332e-4865-a532-a5384d8155c3',
  'Моя Организация',
  'service',
  true,
  '+7 777 123 4567',
  'Алматы, ул. Абая 1',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 2. Создаем пользователя
INSERT INTO users (id, email, "firebaseUid", name, "organizationId", role, "isActive", "createdAt", "updatedAt")
VALUES (
  'b271b798-7a2c-4a52-ad4a-b57652fb8bec',
  'test@test.com',
  'firebase-uid-test',
  'Тестовый Пользователь',
  '41eb0f1f-332e-4865-a532-a5384d8155c3',
  'owner',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 3. Создаем еще организацию для разнообразия
INSERT INTO organizations (id, name, "businessType", "isActive", "phone", "address", "createdAt", "updatedAt")
VALUES (
  '5d99beaf-0a8e-4f75-a0e1-c3470d3eec72',
  'Тестовый Автосервис',
  'service',
  true,
  '+7 777 765 4321',
  'Алматы, ул. Достык 100',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Проверка
SELECT email, name, "organizationId" FROM users;

