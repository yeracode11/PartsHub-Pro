import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DashboardModule } from './dashboard/dashboard.module';
import { OrdersModule } from './orders/orders.module';
import { ItemsModule } from './items/items.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { UsersModule } from './users/users.module';
import { CustomersModule } from './customers/customers.module';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { OrderItemsModule } from './order-items/order-items.module';
import { WhatsAppModule } from './whatsapp/whatsapp.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { B2CModule } from './b2c/b2c.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),

    TypeOrmModule.forRootAsync({
      useFactory: () => ({
        type: 'postgres',
        url: process.env.DATABASE_URL, // 👈 используем именно это
        autoLoadEntities: true,
        synchronize: true, // ⚠️ Временно включено для синхронизации схемы
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined,
      }),
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
