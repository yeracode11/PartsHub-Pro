const jwt = require('jsonwebtoken');

// Тестируем JWT верификацию с тем же секретом что используется в приложении
const secret = 'Rtw+Dir1+3+AgjWFCOHJzQJng3FYhWXoNs5HUCkS23Q=';

// Пример токена из логов (если есть, можно вставить реальный)
const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmOGJlMTkxOC0xMThmLTRjNjMtYmZhZS02MDcxNjkyNmZlY2YiLCJlbWFpbCI6ImVyc3VsMTQzQGdtYWlsLmNvbSIsIm9yZ2FuaXphdGlvbklkIjoiNDFlYjBmMWYtMzMyZS00ODY1LWE1MzItYTUzODRkODE1NWMzIiwicm9sZSI6Im93bmVyIiwiaWF0IjoxNzYxNTg0NjUzLCJleHAiOjE3NjIxODk0NTN9._HuDwvES5p2JlTPTRC3tTEimD3xuvIWYy94OMlyWtOQ';

console.log('🔐 Тестирование JWT верификации...');
console.log('🔑 Секрет:', secret.substring(0, 10) + '...');

try {
  const decoded = jwt.verify(testToken, secret);
  console.log('✅ Токен валиден!');
  console.log('📋 Декодированные данные:', JSON.stringify(decoded, null, 2));
} catch (error) {
  console.log('❌ Ошибка верификации токена:', error.message);
  console.log('💡 Возможные причины:');
  console.log('   - Неправильный JWT_SECRET');
  console.log('   - Токен истек');
  console.log('   - Токен поврежден');
}

// Создаем новый тестовый токен
const testPayload = {
  sub: 'f8be1918-118f-4c63-bfae-60716926fecf',
  email: 'ersul143@gmail.com',
  organizationId: '41eb0f1f-332e-4865-a532-a5384d8155c3',
  role: 'owner',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60 // 7 дней
};

try {
  const newToken = jwt.sign(testPayload, secret, { algorithm: 'HS256' });
  console.log('🔨 Новый тестовый токен:', newToken);

  // Проверяем его обратно
  const verified = jwt.verify(newToken, secret);
  console.log('✅ Новый токен верифицирован:', JSON.stringify(verified, null, 2));
} catch (error) {
  console.log('❌ Ошибка создания токена:', error.message);
}
