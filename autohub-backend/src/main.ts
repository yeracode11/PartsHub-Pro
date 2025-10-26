import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  
  // Включаем CORS для работы с Flutter приложением
  const corsOrigin = process.env.CORS_ORIGIN || '*';
  app.enableCors({
    origin: corsOrigin === '*' ? '*' : corsOrigin.split(','),
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // Настройка статических файлов для загруженных изображений
  app.useStaticAssets(join(__dirname, '..', 'uploads'), {
    prefix: '/uploads/',
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  
  console.log(`🚀 AutoHub Backend запущен на http://localhost:${port}`);
  console.log(`📊 Dashboard API: http://localhost:${port}/api/dashboard/stats`);
  console.log(`📦 Items API: http://localhost:${port}/api/items/popular`);
  console.log(`🛒 Orders API: http://localhost:${port}/api/orders/recent`);
  console.log(`📁 Uploads: http://localhost:${port}/uploads/`);
}
bootstrap();
