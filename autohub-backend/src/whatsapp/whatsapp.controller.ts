import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { WhatsAppService } from './whatsapp.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';

@Controller('api/whatsapp')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WhatsAppController {
  constructor(private readonly whatsappService: WhatsAppService) {}

  /**
   * Проверка статуса WhatsApp клиента
   */
  @Get('status')
  getStatus() {
    const isReady = this.whatsappService.isClientReady();
    const qrCode = this.whatsappService.getQRCode();

    return {
      ready: isReady,
      needsAuth: qrCode !== null,
      message: isReady
        ? 'WhatsApp готов к работе'
        : qrCode
          ? 'Требуется авторизация - отсканируйте QR код'
          : 'Инициализация...',
    };
  }

  /**
   * Получить QR код для авторизации
   */
  @Get('qr')
  getQRCode() {
    const qrCode = this.whatsappService.getQRCode();

    if (!qrCode) {
      return {
        qrCode: null,
        message: 'QR код не требуется или уже авторизовано',
      };
    }

    return {
      qrCode,
      message: 'Отсканируйте этот QR код в WhatsApp',
    };
  }

  /**
   * Отправить одно сообщение
   */
  @Post('send')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async sendMessage(
    @Body() body: { phone: string; message: string },
  ) {
    const { phone, message } = body;

    if (!phone || !message) {
      throw new HttpException(
        'Укажите номер телефона и сообщение',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.whatsappService.sendMessage(phone, message);

      return {
        success: true,
        message: 'Сообщение отправлено',
        phone,
      };
    } catch (error) {
      throw new HttpException(
        error.message || 'Ошибка отправки',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Массовая рассылка
   */
  @Post('send-bulk')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async sendBulk(
    @CurrentUser() user: any,
    @Body()
    body: {
      recipients: Array<{ phone: string; name?: string; customerId?: number }>;
      template: string;
      delayMs?: number;
      campaignName?: string;
    },
  ) {
    const { recipients, template, delayMs = 5000, campaignName } = body;

    if (!recipients || recipients.length === 0) {
      throw new HttpException(
        'Укажите получателей',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (!template) {
      throw new HttpException(
        'Укажите шаблон сообщения',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const results = await this.whatsappService.sendBulk(
        recipients,
        template,
        delayMs,
        {
          organizationId: user.organizationId,
          sentBy: user.userId,
          campaignName,
        },
      );

      return {
        success: true,
        ...results,
        total: recipients.length,
      };
    } catch (error) {
      throw new HttpException(
        error.message || 'Ошибка массовой рассылки',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Принудительное переподключение WhatsApp
   */
  @Post('reconnect')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async reconnect() {
    try {
      await this.whatsappService.reconnect();
      
      return {
        success: true,
        message: 'WhatsApp переподключен',
      };
    } catch (error) {
      throw new HttpException(
        error.message || 'Ошибка переподключения',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Отправить сообщение с медиа
   */
  @Post('send-media')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async sendMedia(
    @Body()
    body: {
      phone: string;
      mediaUrl: string;
      caption?: string;
    },
  ) {
    const { phone, mediaUrl, caption } = body;

    if (!phone || !mediaUrl) {
      throw new HttpException(
        'Укажите номер телефона и URL медиа',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.whatsappService.sendMediaMessage(phone, mediaUrl, caption);

      return {
        success: true,
        message: 'Медиа отправлено',
        phone,
      };
    } catch (error) {
      throw new HttpException(
        error.message || 'Ошибка отправки медиа',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

