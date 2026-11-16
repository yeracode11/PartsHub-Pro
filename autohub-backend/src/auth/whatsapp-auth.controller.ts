import {
  Body,
  ConflictException,
  Controller,
  HttpCode,
  NotFoundException,
  Post,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { PhoneVerificationService } from '../phone-verification/phone-verification.service';
import {
  StartWhatsAppVerificationDto,
  WhatsAppLoginDto,
  WhatsAppResetPasswordDto,
  WhatsAppVerificationStatusDto,
} from '../phone-verification/dto/phone-verification.dto';

/**
 * Бесплатное подтверждение номера через WhatsApp.
 *
 * 1. start → приложение получает код и ссылку wa.me на бота Vinly.
 * 2. Пользователь отправляет код боту (входящее сообщение — бесплатно для бизнеса).
 * 3. Webhook сверяет номер отправителя с введённым номером.
 * 4. status → приложение получает verificationToken и вызывает register/login/reset-password.
 */
@Controller('api/auth/whatsapp')
@UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
export class WhatsAppAuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly phoneVerification: PhoneVerificationService,
  ) {}

  @Post('start')
  async start(@Body() dto: StartWhatsAppVerificationDto) {
    const registered = await this.authService.isPhoneRegistered(dto.phone);
    if (dto.purpose === 'register' && registered) {
      throw new ConflictException(
        'Пользователь с таким телефоном уже зарегистрирован',
      );
    }
    if (dto.purpose !== 'register' && !registered) {
      throw new NotFoundException('Аккаунт с этим номером не найден');
    }
    return this.phoneVerification.start(dto.phone, dto.purpose);
  }

  @Post('status')
  @HttpCode(200)
  status(@Body() dto: WhatsAppVerificationStatusDto) {
    return this.phoneVerification.getStatus(dto.verificationId, dto.secret);
  }

  @Post('login')
  @HttpCode(200)
  login(@Body() dto: WhatsAppLoginDto) {
    return this.authService.loginWithWhatsApp(dto.verificationToken);
  }

  @Post('reset-password')
  @HttpCode(200)
  resetPassword(@Body() dto: WhatsAppResetPasswordDto) {
    return this.authService.resetPasswordWithWhatsApp(
      dto.verificationToken,
      dto.newPassword,
    );
  }
}
