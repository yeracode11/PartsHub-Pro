-- Проверить пользователя в БД
SELECT 
    id,
    email,
    name,
    "firebaseUid",
    "organizationId",
    role,
    "isActive",
    CASE 
        WHEN password IS NULL THEN '❌ Password NOT SET'
        WHEN password = '' THEN '❌ Password EMPTY'
        ELSE '✅ Password SET'
    END as password_status,
    "createdAt",
    "updatedAt"
FROM users
WHERE email = 'ersul143@gmail.com';

-- Проверить организацию
SELECT 
    id,
    name,
    "businessType",
    "isActive"
FROM organizations
WHERE id = '41eb0f1f-332e-4865-a532-a5384d8155c3';

