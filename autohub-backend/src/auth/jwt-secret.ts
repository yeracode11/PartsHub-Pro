import { ConfigService } from '@nestjs/config';

const DEV_ONLY_SECRET = 'partshub-local-development-secret';

/**
 * В production без JWT_SECRET приложение не стартует: известный секрет позволил бы подделать токен.
 */
export function resolveJwtSecret(config: ConfigService): string {
  const secret = config.get<string>('JWT_SECRET')?.trim();
  if (secret) return secret;

  const env = (config.get<string>('NODE_ENV') || '').trim();
  if (env === 'development' || env === 'test') {
    return DEV_ONLY_SECRET;
  }
  throw new Error('JWT_SECRET is required outside development');
}
