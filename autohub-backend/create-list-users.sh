#!/bin/bash

# Скрипт для создания list-users.js на сервере
# Использование: bash create-list-users.sh

cat > list-users.js << 'EOFSCRIPT'
#!/usr/bin/env node

/**
 * Скрипт для вывода списка пользователей из базы данных
 */

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Загрузка переменных окружения из .env файла
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split('\n').forEach(line => {
      const trimmedLine = line.trim();
      if (trimmedLine && !trimmedLine.startsWith('#')) {
        const [key, ...valueParts] = trimmedLine.split('=');
        const value = valueParts.join('=').trim();
        if (key && value) {
          process.env[key.trim()] = value.replace(/^["']|["']$/g, '');
        }
      }
    });
  }
}

loadEnv();

// Конфигурация подключения к БД
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'autohubdb',
};

if (process.env.DATABASE_URL) {
  const url = new URL(process.env.DATABASE_URL);
  dbConfig.host = url.hostname;
  dbConfig.port = parseInt(url.port || '5432', 10);
  dbConfig.user = decodeURIComponent(url.username);
  dbConfig.password = decodeURIComponent(url.password || '');
  dbConfig.database = url.pathname.slice(1);
}

async function listUsers() {
  const client = new Client(dbConfig);

  try {
    console.log('🔌 Подключение к базе данных...');
    console.log(`   Host: ${dbConfig.host}:${dbConfig.port}`);
    console.log(`   Database: ${dbConfig.database}`);
    console.log(`   User: ${dbConfig.user}`);
    
    await client.connect();
    console.log('✅ Подключение установлено\n');

    const query = `
      SELECT 
        u.id,
        u.email,
        u.name,
        u.role,
        u."isActive",
        u."firebaseUid",
        u."organizationId",
        o.name as "organizationName",
        u."createdAt",
        u."updatedAt"
      FROM users u
      LEFT JOIN organizations o ON u."organizationId" = o.id
      ORDER BY u."createdAt" DESC
    `;

    const result = await client.query(query);

    if (result.rows.length === 0) {
      console.log('📭 Пользователи не найдены');
      return;
    }

    console.log(`📋 Найдено пользователей: ${result.rows.length}\n`);
    console.log('═'.repeat(120));
    console.log(
      'ID'.padEnd(38) + ' | ' +
      'Email'.padEnd(30) + ' | ' +
      'Имя'.padEnd(20) + ' | ' +
      'Роль'.padEnd(12) + ' | ' +
      'Организация'.padEnd(20) + ' | ' +
      'Активен'
    );
    console.log('═'.repeat(120));

    result.rows.forEach((user) => {
      const id = user.id.substring(0, 8) + '...';
      const email = (user.email || '').substring(0, 28);
      const name = (user.name || '').substring(0, 18);
      const role = (user.role || '').substring(0, 10);
      const orgName = (user.organizationName || 'N/A').substring(0, 18);
      const isActive = user.isActive ? '✅' : '❌';

      console.log(
        id.padEnd(38) + ' | ' +
        email.padEnd(30) + ' | ' +
        name.padEnd(20) + ' | ' +
        role.padEnd(12) + ' | ' +
        orgName.padEnd(20) + ' | ' +
        isActive
      );
    });

    console.log('═'.repeat(120));
    console.log(`\n📊 Статистика:`);
    
    const roleStats = {};
    result.rows.forEach(user => {
      roleStats[user.role] = (roleStats[user.role] || 0) + 1;
    });
    
    console.log('\n👥 По ролям:');
    Object.entries(roleStats).forEach(([role, count]) => {
      console.log(`   ${role}: ${count}`);
    });

    const activeCount = result.rows.filter(u => u.isActive).length;
    const inactiveCount = result.rows.filter(u => !u.isActive).length;
    console.log(`\n✅ Активных: ${activeCount}`);
    console.log(`❌ Неактивных: ${inactiveCount}`);

    const orgStats = {};
    result.rows.forEach(user => {
      const orgName = user.organizationName || 'Без организации';
      orgStats[orgName] = (orgStats[orgName] || 0) + 1;
    });
    
    console.log('\n🏢 По организациям:');
    Object.entries(orgStats).forEach(([org, count]) => {
      console.log(`   ${org}: ${count}`);
    });

    if (process.argv.includes('--detailed') || process.argv.includes('-d')) {
      console.log('\n\n📝 Детальная информация:\n');
      result.rows.forEach((user, index) => {
        console.log(`${index + 1}. ${user.name} (${user.email})`);
        console.log(`   ID: ${user.id}`);
        console.log(`   Роль: ${user.role}`);
        console.log(`   Организация: ${user.organizationName || 'N/A'} (${user.organizationId})`);
        console.log(`   Firebase UID: ${user.firebaseUid || 'N/A'}`);
        console.log(`   Статус: ${user.isActive ? 'Активен' : 'Неактивен'}`);
        console.log(`   Создан: ${new Date(user.createdAt).toLocaleString('ru-RU')}`);
        console.log(`   Обновлён: ${new Date(user.updatedAt).toLocaleString('ru-RU')}`);
        console.log('');
      });
    }

  } catch (error) {
    console.error('❌ Ошибка:', error.message);
    if (error.code === 'ECONNREFUSED') {
      console.error('   Не удалось подключиться к базе данных. Проверьте:');
      console.error('   - Запущена ли база данных');
      console.error('   - Правильность настроек подключения в .env');
    } else if (error.code === '28P01') {
      console.error('   Ошибка аутентификации. Проверьте пароль в .env');
    }
    process.exit(1);
  } finally {
    await client.end();
    console.log('\n✅ Соединение закрыто');
  }
}

listUsers().catch(error => {
  console.error('❌ Критическая ошибка:', error);
  process.exit(1);
});
EOFSCRIPT

chmod +x list-users.js
echo "✅ Файл list-users.js создан!"
echo ""
echo "Теперь можно запустить:"
echo "  node list-users.js"
echo "  node list-users.js --detailed"
