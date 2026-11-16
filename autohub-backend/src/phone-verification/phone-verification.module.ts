import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { resolveJwtSecret } from '../auth/jwt-secret';
import { PhoneVerification } from './entities/phone-verification.entity';
import { PhoneVerificationService } from './phone-verification.service';

/** Не зависит ни от Auth, ни от WhatsApp: используется обоими. */
@Module({
  imports: [
    TypeOrmModule.forFeature([PhoneVerification]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        // Отдельный секрет: токен подтверждения номера не должен приниматься
        // как access/refresh token (в нём нет sub пользователя).
        secret: `${resolveJwtSecret(config)}:phone-verification`,
        signOptions: { algorithm: 'HS256' as const },
      }),
      inject: [ConfigService],
    }),
  ],
  providers: [PhoneVerificationService],
  exports: [PhoneVerificationService],
})
export class PhoneVerificationModule {}
