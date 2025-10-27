import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DashboardModule } from './dashboard/dashboard.module';
import { OrdersModule } from './orders/orders.module';
import { ItemsModule } from './items/items.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { UsersModule } from './users/users.module';
import { CustomersModule } from './customers/customers.module';
import { AuthModule } from './auth/auth.module';
import { OrderItemsModule } from './order-items/order-items.module';
import { WhatsAppModule } from './whatsapp/whatsapp.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { B2CModule } from './b2c/b2c.module';

@Module({
  imports: [
    // PostgreSQL + TypeORM настройка
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      username: process.env.DB_USER || 'eracode', // macOS username
      password: process.env.DB_PASSWORD || '', // По умолчанию пусто
      database: process.env.DB_NAME || 'autohub',
      entities: [__dirname + '/**/*.entity{.ts,.js}'],
      synchronize: process.env.NODE_ENV !== 'production', // false в production
      logging: process.env.NODE_ENV === 'development',
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined,
    }),
    AuthModule,
    DashboardModule,
    OrdersModule,
    OrderItemsModule,
    ItemsModule,
    OrganizationsModule,
    UsersModule,
    CustomersModule,
    WhatsAppModule,
    VehiclesModule,
    B2CModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
