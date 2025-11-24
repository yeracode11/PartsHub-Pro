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
        // Явно преобразуем пароль в строку (критично для PostgreSQL)
        const dbPassword = process.env.DB_PASSWORD 
          ? String(process.env.DB_PASSWORD).trim() 
          : '';

        // Используем отдельные переменные окружения для большей надежности
        const config: any = {
          type: 'postgres',
          host: process.env.DB_HOST || 'localhost',
          port: parseInt(process.env.DB_PORT || '5432', 10),
          username: process.env.DB_USER || 'postgres',
          password: dbPassword, // Явно как строка
          database: process.env.DB_NAME || 'autohubdb',
          autoLoadEntities: true,
          synchronize: process.env.NODE_ENV !== 'production', // Отключено в production
        };

        // Если есть DATABASE_URL, парсим его и используем отдельные параметры
        // Это более надежно, чем передавать URL напрямую
        if (process.env.DATABASE_URL) {
          try {
            const url = new URL(process.env.DATABASE_URL);
            config.host = url.hostname;
            config.port = parseInt(url.port || '5432', 10);
            config.username = decodeURIComponent(url.username);
            // Пароль из URL - явно как строка
            config.password = url.password ? String(decodeURIComponent(url.password)) : '';
            config.database = url.pathname.slice(1); // Убираем первый /
          } catch (error) {
            console.error('❌ Error parsing DATABASE_URL:', error);
            // Продолжаем с отдельными переменными
          }
        }

        // SSL только в production
        if (process.env.NODE_ENV === 'production') {
          config.ssl = { rejectUnauthorized: false };
        }

        // Логирование для диагностики
        console.log('🔌 Database config:', {
          host: config.host,
          port: config.port,
          username: config.username,
          database: config.database,
          passwordType: typeof config.password,
          passwordLength: config.password ? config.password.length : 0,
          passwordSet: !!config.password,
          hasDatabaseUrl: !!process.env.DATABASE_URL,
        });

        // Критическая проверка: пароль должен быть строкой
        if (typeof config.password !== 'string') {
          console.error('❌ CRITICAL: password is not a string!', typeof config.password);
          config.password = String(config.password || '');
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
