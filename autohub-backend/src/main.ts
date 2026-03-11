import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { WinstonModule, utilities } from 'nest-winston';
import * as winston from 'winston';
import LokiTransport from 'winston-loki';

function createAppLogger() {
  const serviceName = process.env.LOKI_SERVICE_NAME || 'autohub-backend';
  const environment = process.env.LOKI_ENV || process.env.NODE_ENV || 'development';
  const lokiHost = process.env.LOKI_HOST?.trim();

  const transports: winston.transport[] = [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        utilities.format.nestLike(serviceName, { prettyPrint: true }),
      ),
    }),
  ];

  if (lokiHost) {
    transports.push(
      new LokiTransport({
        host: lokiHost,
        labels: {
          app: serviceName,
          env: environment,
        },
        json: true,
        replaceTimestamp: true,
        basicAuth:
          process.env.LOKI_USERNAME && process.env.LOKI_PASSWORD
            ? `${process.env.LOKI_USERNAME}:${process.env.LOKI_PASSWORD}`
            : undefined,
        onConnectionError: (error) => {
          // Важно не падать при недоступности Loki
          const message = error instanceof Error ? error.message : String(error);
          console.error('[Loki] connection error:', message);
        },
      }),
    );
  }

  return WinstonModule.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    transports,
  });
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: createAppLogger(),
  });
  
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
  const host = process.env.HOST || '0.0.0.0'; // Слушаем на всех интерфейсах для доступа извне
  
  await app.listen(port, host);
}
bootstrap();
