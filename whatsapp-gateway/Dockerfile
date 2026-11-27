FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY tsconfig.json ./
COPY src ./src
COPY test ./test
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
# Сессии магазинов (вход по QR) лежат здесь — это volume, иначе после пересборки все отвяжутся.
VOLUME ["/app/sessions"]
ENV SESSIONS_DIR=/app/sessions
EXPOSE 3005
CMD ["node", "dist/src/main.js"]
