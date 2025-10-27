import 'dotenv/config';
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  // 👇 Включаем synchronize только в режиме разработки
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV !== 'production',
  entities: ['dist/**/*.entity.js'],
  migrations: ['dist/migrations/*.js'],
});
