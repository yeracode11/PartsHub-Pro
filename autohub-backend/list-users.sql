-- SQL скрипт для вывода списка пользователей
-- Использование: psql -U eracode -d autohubdb -f list-users.sql

-- Простой список всех пользователей
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u."isActive",
  u."firebaseUid",
  o.name as "organizationName",
  u."createdAt",
  u."updatedAt"
FROM users u
LEFT JOIN organizations o ON u."organizationId" = o.id
ORDER BY u."createdAt" DESC;

-- Статистика по ролям
SELECT 
  role,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE "isActive" = true) as active_count,
  COUNT(*) FILTER (WHERE "isActive" = false) as inactive_count
FROM users
GROUP BY role
ORDER BY count DESC;

-- Статистика по организациям
SELECT 
  o.name as "organizationName",
  COUNT(u.id) as user_count,
  COUNT(u.id) FILTER (WHERE u."isActive" = true) as active_users
FROM organizations o
LEFT JOIN users u ON o.id = u."organizationId"
GROUP BY o.id, o.name
ORDER BY user_count DESC;
