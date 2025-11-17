#!/bin/bash

# Скрипт для обновления и перезапуска бэкенда с исправлением incoming

echo "🔄 Обновление кода..."
cd /var/www/PartsHub-Pro/autohub-backend
git pull origin main

echo "📦 Установка зависимостей..."
npm install

echo "🔨 Сборка проекта..."
npm run build

echo "🔄 Перезапуск PM2..."
pm2 restart autohub-backend

echo "✅ Готово! Проверьте логи:"
echo "   pm2 logs autohub-backend --lines 50"

