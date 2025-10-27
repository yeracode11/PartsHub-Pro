import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';

dotenv.config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  synchronize: true, // true только при первом запуске для создания таблиц
  logging: true,
  entities: ['dist/**/*.entity.js'], // путь к собранным Entity
  migrations: ['dist/migrations/*.js'], // путь к собранным миграциям
});
