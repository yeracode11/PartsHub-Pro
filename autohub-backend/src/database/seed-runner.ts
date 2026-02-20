import { DataSource } from 'typeorm';
import { seedDatabase } from './seed';

const dataSource = new DataSource({
  type: 'postgres',
  host: 'localhost',
  port: 5432,
  username: 'eracode',
  password: '',
  database: 'autohub',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  synchronize: false,
});

async function run() {
  try {
    await dataSource.initialize();
    
    await seedDatabase(dataSource);
    
    await dataSource.destroy();
    process.exit(0);
  } catch (error) {
    process.exit(1);
  }
}

run();

