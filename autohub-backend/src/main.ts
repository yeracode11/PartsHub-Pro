import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { WinstonModule, utilities } from 'nest-winston';
import * as winston from 'winston';
import axios from 'axios';
import { Writable } from 'stream';

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
    const normalizedHost = lokiHost.replace(/\/+$/, '');
    const basicAuth =
      process.env.LOKI_USERNAME && process.env.LOKI_PASSWORD
        ? `${process.env.LOKI_USERNAME}:${process.env.LOKI_PASSWORD}`
        : undefined;
    const authHeader = basicAuth
      ? { Authorization: `Basic ${Buffer.from(basicAuth).toString('base64')}` }
      : {};

    // Fallback transport: ship every formatted log line to Loki via HTTP API.
    // This is more predictable than winston-loki for our deployment.
    const lokiStream = new Writable({
      write(chunk, _encoding, callback) {
        const line = chunk.toString().trim();
        if (!line) {
          callback();
          return;
        }

        const timestampNs = (BigInt(Date.now()) * 1000000n).toString();
        const payload = {
          streams: [
            {
              stream: {
                app: serviceName,
                env: environment,
              },
              values: [[timestampNs, line]],
            },
          ],
        };

        void axios
          .post(`${normalizedHost}/loki/api/v1/push`, payload, {
            timeout: 10000,
            headers: {
              'Content-Type': 'application/json',
              ...authHeader,
            },
          })
          .catch((error: unknown) => {
            const message = error instanceof Error ? error.message : String(error);
            console.error('[Loki] push error:', message);
          });

        callback();
      },
    });

    transports.push(
      new winston.transports.Stream({
        stream: lokiStream,
      }),
    );
  }

  return WinstonModule.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    transports,
  });
}

async function bootstrap() {
  const appLogger = createAppLogger();
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: appLogger,
  });
  appLogger.log(
    `Loki bootstrap log. env=${process.env.LOKI_ENV || process.env.NODE_ENV || 'development'}`,
    'Bootstrap',
  );
  
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
  appLogger.log(`HTTP server started on ${host}:${port}`, 'Bootstrap');
}
bootstrap();
