// Проверка подключения к БД
const { DataSource } = require('typeorm');

const dataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://eracode:erasoft123@localhost:5432/autohubdb',
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined,
  synchronize: false,
});

async function testConnection() {
  try {
    console.log('🔍 Тестирование подключения к БД...');
    await dataSource.initialize();
    console.log('✅ Подключение к БД успешно');

    // Проверяем наличие таблиц
    const tables = await dataSource.query(`
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public'
      AND tablename IN ('users', 'organizations', 'items', 'orders', 'customers')
    `);

    console.log('📋 Найденные таблицы:', tables.map(t => t.tablename));

    // Проверяем данные пользователя
    const users = await dataSource.query(`
      SELECT id, email, "firebaseUid", "organizationId", role, "isActive"
      FROM users
      WHERE email = 'ersul143@gmail.com'
    `);

    console.log('👤 Пользователь:', users[0] || 'не найден');

    if (users[0]) {
      // Проверяем организацию
      const orgs = await dataSource.query(`
        SELECT id, name, "businessType", "isActive"
        FROM organizations
        WHERE id = $1
      `, [users[0].organizationId]);

      console.log('🏢 Организация:', orgs[0] || 'не найдена');
    }

    await dataSource.destroy();
    console.log('✅ Тест завершен');

  } catch (error) {
    console.error('❌ Ошибка подключения к БД:', error.message);
    console.error('📋 Детали:', error);
  }
}

testConnection();
