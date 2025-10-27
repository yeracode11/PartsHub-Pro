FROM node:20-alpine

WORKDIR /app

# Копируем package files
COPY package*.json ./

# Устанавливаем зависимости
RUN npm ci --only=production

# Копируем исходный код
COPY . .

# Собираем приложение
RUN npm run build

# Создаем директорию для загрузок
RUN mkdir -p uploads/items

# Expose порт
EXPOSE 3000

# Запускаем приложение
CMD ["node", "dist/main.js"]

