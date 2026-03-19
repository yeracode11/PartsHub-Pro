import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpException,
  HttpStatus,
  Logger,
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
  private readonly logger = new Logger(WhatsAppController.name);

  constructor(private readonly whatsappService: WhatsAppService) {}

  /**
   * Проверка статуса WhatsApp клиента.
   * При отсутствии состояния вызывает инициализацию (refreshState), чтобы получить актуальный статус.
   */
  @Get('status')
  async getStatus(@CurrentUser() user: any) {
    const userId = user.userId || user.id;

    try {
      // Инициализируем сессию, если ещё нет состояния — иначе будет бесконечная "Инициализация..."
      const hasState = this.whatsappService.isClientReady(userId) ||
        this.whatsappService.getLastError(userId) != null ||
        this.whatsappService.getQRCode(userId) != null;
      if (!hasState) {
        await this.whatsappService.initializeUserSession(userId).catch((err) => {
          this.logger.warn(`Status init: ${err?.message || err}`);
        });
      }

      const isReady = this.whatsappService.isClientReady(userId);
      const qrCode = this.whatsappService.getQRCode(userId);
      const needsReauth = this.whatsappService.needsReauth(userId);
      const lastError = this.whatsappService.getLastError(userId);

      return {
        ready: isReady,
        needsAuth: qrCode !== null || needsReauth,
        lastError,
        message: isReady
          ? 'WhatsApp готов к работе'
          : qrCode || needsReauth
            ? 'Требуется авторизация в Green API'
            : lastError
              ? `Ошибка подключения: ${lastError}`
              : 'Инициализация...',
      };
    } catch (err: any) {
      this.logger.error(`Status error: ${err?.message}`, err?.stack);
      return {
        ready: false,
        needsAuth: true,
        lastError: err?.message || 'Ошибка проверки статуса',
        message: `Ошибка: ${err?.message || 'Не удалось проверить статус'}`,
      };
    }
  }

  /**
   * Получить QR код для авторизации.
   * Не выбрасывает 500 — всегда возвращает 200 с qrCode или сообщением об ошибке.
   */
  @Get('qr')
  async getQRCode(@CurrentUser() user: any) {
    const userId = user.userId || user.id;

    try {
      await this.whatsappService.initializeUserSession(userId).catch((err) => {
        this.logger.warn(`QR init: ${err?.message || err}`);
      });

      let qrCode = this.whatsappService.getQRCode(userId);

      if (!qrCode && !this.whatsappService.isClientReady(userId)) {
        await this.whatsappService.forceReauth(userId, 'qr_request').catch((err) => {
          this.logger.warn(`QR forceReauth: ${err?.message || err}`);
        });
        qrCode = this.whatsappService.getQRCode(userId);
      }

      const lastError = this.whatsappService.getLastError(userId);

      if (!qrCode) {
        return {
          qrCode: null,
          message:
            lastError ||
            'QR недоступен через API. Авторизуйте инстанс в Green API кабинете.',
        };
      }

      return {
        qrCode,
        message: 'Отсканируйте QR код для авторизации Green API',
      };
    } catch (err: any) {
      this.logger.error(`QR error: ${err?.message}`, err?.stack);
      return {
        qrCode: null,
        message: err?.message || 'Не удалось получить QR код',
      };
    }
  }

  /**
   * Отправить одно сообщение
   */
  @Post('send')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async sendMessage(
    @CurrentUser() user: any,
    @Body() body: { phone: string; message: string },
  ) {
    const { phone, message } = body;
    const userId = user.userId || user.id;

    if (!phone || !message) {
      throw new HttpException(
        'Укажите номер телефона и сообщение',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.whatsappService.sendMessage(userId, phone, message);

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

    const userId = user.userId || user.id;
    
    // Проверяем статус WhatsApp перед рассылкой
    const isReady = this.whatsappService.isClientReady(userId);
    if (!isReady) {
      throw new HttpException(
        'WhatsApp клиент не готов. Проверьте подключение и отсканируйте QR код при необходимости.',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    try {
      const results = await this.whatsappService.sendBulk(
        userId,
        recipients,
        template,
        delayMs,
        {
          organizationId: user.organizationId,
          sentBy: userId,
          campaignName,
        },
      );

      return {
        success: true,
        ...results,
        total: recipients.length,
      };
    } catch (error) {
      this.logger.error(
        'Ошибка массовой рассылки',
        error.stack,
      );

      throw new HttpException(
        error.message || 'Ошибка массовой рассылки',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Принудительное переподключение WhatsApp (logout + получение нового QR).
   * Всегда возвращает 200 с success/message/qrCode — без 500.
   */
  @Post('reconnect')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async reconnect(@CurrentUser() user: any) {
    const userId = user?.userId ?? user?.id ?? 'unknown';

    try {
      await this.whatsappService.reconnect(userId);
      const qrCode = this.whatsappService.getQRCode(userId);
      const lastError = this.whatsappService.getLastError(userId);
      const isReady = this.whatsappService.isClientReady(userId);

      return {
        success: !!qrCode || isReady,
        message: qrCode ? 'Отсканируйте QR код' : (lastError || 'WhatsApp переподключен'),
        qrCode: qrCode ?? null,
      };
    } catch (error: any) {
      const msg = String(error?.message || error || 'Ошибка переподключения');
      this.logger.error(`Reconnect failed: ${msg}`, error?.stack);

      let qrCode: string | null = null;
      try {
        qrCode = this.whatsappService.getQRCode(userId);
      } catch (_) {}

      return {
        success: false,
        message: msg,
        qrCode: qrCode ?? null,
      };
    }
  }

  /**
   * Выйти из WhatsApp аккаунта
   */
  @Post('logout')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async logout(@CurrentUser() user: any) {
    const userId = user.userId || user.id;
    
    try {
      await this.whatsappService.logout(userId);
      
      return {
        success: true,
        message: 'Вы успешно вышли из WhatsApp',
      };
    } catch (error) {
      throw new HttpException(
        error.message || 'Ошибка выхода из аккаунта',
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
    @CurrentUser() user: any,
    @Body()
    body: {
      phone: string;
      mediaUrl: string;
      caption?: string;
    },
  ) {
    const { phone, mediaUrl, caption } = body;
    const userId = user.userId || user.id;

    if (!phone || !mediaUrl) {
      throw new HttpException(
        'Укажите номер телефона и URL медиа',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.whatsappService.sendMediaMessage(userId, phone, mediaUrl, caption);

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

