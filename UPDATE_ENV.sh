#!/bin/bash

echo "🔧 Обновление .env на сервере..."

cd /var/www/PartsHub-Pro/autohub-backend

echo "📝 Создание/обновление .env файла..."

cat > .env << 'EOF'
# Node Environment
NODE_ENV=production

# Port
PORT=3000

# Database Configuration
DATABASE_URL=postgresql://eracode:erasoft123@localhost:5432/autohubdb

# JWT Secret
JWT_SECRET=Rtw+Dir1+3+AgjWFCOHJzQJng3FYhWXoNs5HUCkS23Q=

# CORS Origin для мобильных приложений
CORS_ORIGIN=*

# Upload Directory
UPLOAD_DIR=./uploads
EOF

echo "✅ .env файл обновлен!"
echo ""
echo "📋 Содержимое:"
cat .env
echo ""
echo "🔄 Перезапустите бэкенд:"
echo "   cd /var/www/PartsHub-Pro/autohub-backend"
echo "   pm2 restart autohub-backend"

