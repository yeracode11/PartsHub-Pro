import 'dotenv/config';
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 5432,
    username: process.env.DB_USER || 'eracode',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'autohubdb', // <- обязательно autohubdb
    synchronize: false,
    logging: false,
    entities: [__dirname + '/**/*.entity{.ts,.js}'],
    migrations: [__dirname + '/migrations/*{.ts,.js}'],
    subscribers: [],
  });
  
