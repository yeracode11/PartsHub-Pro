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
import { IncomingModule } from './incoming/incoming.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),

    TypeOrmModule.forRootAsync({
      useFactory: () => {
        // Используем отдельные переменные окружения для большей надежности
        const config: any = {
          type: 'postgres',
          host: process.env.DB_HOST || 'localhost',
          port: parseInt(process.env.DB_PORT || '5432', 10),
          username: process.env.DB_USER || 'postgres',
          password: process.env.DB_PASSWORD || '', // Явно как строка
          database: process.env.DB_NAME || 'autohubdb',
          autoLoadEntities: true,
          synchronize: process.env.NODE_ENV !== 'production', // Отключено в production
        };

        // Если есть DATABASE_URL, используем его (приоритет)
        if (process.env.DATABASE_URL) {
          config.url = process.env.DATABASE_URL;
        }

        // SSL только в production
        if (process.env.NODE_ENV === 'production') {
          config.ssl = { rejectUnauthorized: false };
        }

        // Логирование для отладки (только если пароль не пустой)
        if (process.env.NODE_ENV !== 'production') {
          console.log('🔌 Database config:', {
            host: config.host,
            port: config.port,
            username: config.username,
            database: config.database,
            passwordSet: !!config.password,
            hasUrl: !!config.url,
          });
        }

        return config;
      },
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
    IncomingModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
