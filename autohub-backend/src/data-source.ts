import 'dotenv/config';
import * as path from 'path';
import { DataSource } from 'typeorm';

/**
 * DataSource только для CLI TypeORM (`typeorm-ts-node-commonjs`).
 * Должен быть синхронизирован с настройками БД из app.module.ts.
 * Запуск: npm run migration:run   |   npm run migration:generate --
 */
export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 5432,
  username: process.env.DB_USER || 'eracode',
  password: process.env.DB_PASSWORD || 'erasoft123',
  database: process.env.DB_NAME || 'autohubdb',
  synchronize: false,
  logging: false,
  entities: [path.join(__dirname, '**/*.entity{.ts,.js}')],
  migrations: [path.join(__dirname, 'migrations/*{.ts,.js}')],
  subscribers: [],
});
