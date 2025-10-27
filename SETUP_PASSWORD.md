# Установка пароля для входа в систему

## Проблема
Ошибка 500 при входе - пользователь не имеет пароля в базе данных.

## Решение

### На сервере выполните:

```bash
cd /home/PartsHub-Pro
git pull origin main

# Перезапустить бэкенд
cd autohub-backend
npm install
npm run build
pm2 restart autohub-backend

# Применить SQL для установки пароля
psql -h localhost -U eracode -d AutohubDB -f autohub-backend/setup-password.sql
```

### Или вручную через psql:

```sql
-- Обновить пароль для пользователя
UPDATE users 
SET password = '$2b$10$r8rsXwuFSUQn82Hq10f7gu.FjD.ISHt.sVE1LEvyBUKGlhxzETCUK',
    "updatedAt" = NOW()
WHERE email = 'ersul143@gmail.com';

-- Создать организацию если её нет
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

-- Обновить organizationId для пользователя
UPDATE users 
SET "organizationId" = '41eb0f1f-332e-4865-a532-a5384d8155c3'
WHERE email = 'ersul143@gmail.com';
```

## Данные для входа

📧 Email: `ersul143@gmail.com`  
🔑 Password: `admin123`

## Генерация нового хеша пароля

Если нужно изменить пароль, на сервере выполните:

```bash
cd /home/PartsHub-Pro/autohub-backend
node -e "const bcrypt=require('bcrypt');bcrypt.hash('YOUR_PASSWORD',10).then(h=>console.log(h))"
```

Затем обновите значение в SQL запросе выше.

