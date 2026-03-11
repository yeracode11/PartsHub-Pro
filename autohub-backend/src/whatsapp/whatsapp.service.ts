import { Injectable, Logger, OnModuleInit, Inject } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { MessageHistoryService } from './message-history.service';
import { MessageStatus } from './entities/message-history.entity';
import { VehiclesService } from '../vehicles/vehicles.service';
import { TemplatesService } from './templates.service';

interface UserState {
  isReady: boolean;
  qrCode: string | null;
  needsReauth: boolean;
  lastError: string | null;
}

@Injectable()
export class WhatsAppService implements OnModuleInit {
  private readonly logger = new Logger(WhatsAppService.name);
  private userStates: Map<string, UserState> = new Map();

  private readonly apiUrl =
    process.env.GREEN_API_URL || 'https://7105.api.greenapi.com';
  private readonly idInstance =
    process.env.GREEN_API_ID_INSTANCE || '7105313983';
  private readonly apiTokenInstance = process.env.GREEN_API_TOKEN_INSTANCE || '';
  private readonly instanceName =
    process.env.GREEN_API_INSTANCE_NAME || this.idInstance;

  constructor(
    @Inject(MessageHistoryService)
    private readonly historyService: MessageHistoryService,
    private readonly vehiclesService: VehiclesService,
    private readonly templatesService: TemplatesService,
  ) {}

  async onModuleInit() {
    this.logger.log(
      `📱 WhatsApp service via Green API initialized (instance: ${this.instanceName})`,
    );
  }

  async initializeUserSession(userId: string): Promise<void> {
    await this.refreshState(userId);
  }

  isClientReady(userId: string): boolean {
    return this.userStates.get(userId)?.isReady || false;
  }

  getQRCode(userId: string): string | null {
    return this.userStates.get(userId)?.qrCode || null;
  }

  needsReauth(userId: string): boolean {
    return this.userStates.get(userId)?.needsReauth || false;
  }

  getLastError(userId: string): string | null {
    return this.userStates.get(userId)?.lastError || null;
  }

  async forceReauth(userId: string, reason: string = 'manual'): Promise<void> {
    this.logger.warn(
      `🔐 Green API: marked reauth required (${reason}) for user ${userId}`,
    );
    const current = this.userStates.get(userId) ?? this.getDefaultState();
    this.userStates.set(userId, {
      ...current,
      isReady: false,
      needsReauth: true,
      qrCode: null,
      lastError:
        'Требуется авторизация в Green API (личный кабинет / мобильное устройство).',
    });
  }

  async sendMessage(
    userId: string,
    phone: string,
    message: string,
    retries: number = 3,
  ): Promise<void> {
    if (!this.apiTokenInstance) {
      throw new Error(
        'GREEN_API_TOKEN_INSTANCE не задан. Добавьте токен инстанса в env.',
      );
    }

    await this.refreshState(userId);
    if (!this.isClientReady(userId)) {
      throw new Error(
        'WhatsApp не готов в Green API. Выполните авторизацию инстанса.',
      );
    }

    const formattedPhone = this.formatPhoneNumber(phone);
    const chatId = this.toChatId(formattedPhone);

    let lastError: Error | null = null;
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await this.greenApiPost('sendMessage', {
          chatId,
          message,
          linkPreview: false,
        });
        this.setReadyState(userId, true);
        return;
      } catch (error) {
        lastError = error as Error;
        const msg = (lastError.message || '').toLowerCase();
        if (
          msg.includes('401') ||
          msg.includes('unauthorized') ||
          msg.includes('not authorized') ||
          msg.includes('not logged')
        ) {
          this.setReadyState(userId, false, {
            needsReauth: true,
            lastError: 'Инстанс Green API не авторизован.',
          });
          throw new Error(
            'Инстанс Green API не авторизован. Выполните авторизацию и повторите.',
          );
        }
        if (attempt < retries) {
          await this.delay(attempt * 2000);
        }
      }
    }

    throw new Error(
      `Не удалось отправить сообщение после ${retries} попыток: ${lastError?.message || 'Unknown error'}`,
    );
  }

  async sendBulk(
    userId: string,
    recipients: Array<{ phone: string; name?: string; customerId?: number }>,
    template: string,
    delayMs: number = 5000,
    options?: {
      organizationId: string;
      sentBy: string;
      campaignName?: string;
    },
  ): Promise<{ sent: number; failed: number; errors: string[] }> {
    await this.refreshState(userId);
    if (!this.isClientReady(userId)) {
      throw new Error('WhatsApp клиент не готов');
    }

    const results = { sent: 0, failed: 0, errors: [] as string[] };

    for (const recipient of recipients) {
      let status = MessageStatus.SENT;
      let errorMessage = null;

      try {
        let carModelText = 'автомобиль';
        if (recipient.customerId && options?.organizationId) {
          try {
            const customerId =
              typeof recipient.customerId === 'number'
                ? recipient.customerId
                : parseInt(String(recipient.customerId), 10);
            if (!isNaN(customerId)) {
              const vehicles = await this.vehiclesService.findByCustomer(
                options.organizationId,
                customerId,
              );
              if (vehicles?.length) {
                const vehicle = vehicles[0];
                carModelText = vehicle.year
                  ? `${vehicle.brand} ${vehicle.model} ${vehicle.year}`
                  : `${vehicle.brand} ${vehicle.model}`;
              }
            }
          } catch (_) {}
        }

        const variables: Record<string, string> = {
          name: recipient.name || 'Уважаемый клиент',
          carModel: carModelText,
        };
        if (options?.organizationId) {
          variables.organizationName = 'наш сервис';
        }

        const personalizedMessage = this.templatesService.fillTemplate(
          template,
          variables,
        );
        await this.sendMessage(userId, recipient.phone, personalizedMessage);
        results.sent++;
      } catch (error) {
        results.failed++;
        results.errors.push(`${recipient.phone}: ${error.message}`);
        status = MessageStatus.FAILED;
        errorMessage = error.message;
      }

      if (options) {
        try {
          await this.historyService.create({
            organizationId: options.organizationId,
            sentBy: options.sentBy,
            customerId: recipient.customerId,
            phone: recipient.phone,
            message: template,
            status,
            errorMessage,
            isBulk: true,
            campaignName: options.campaignName,
          });
        } catch (_) {}
      }

      if (delayMs > 0) {
        await this.delay(delayMs);
      }
    }

    return results;
  }

  async sendMediaMessage(
    userId: string,
    phone: string,
    mediaUrl: string,
    caption?: string,
  ): Promise<void> {
    await this.refreshState(userId);
    if (!this.isClientReady(userId)) {
      throw new Error('WhatsApp клиент не готов');
    }

    const formattedPhone = this.formatPhoneNumber(phone);
    const chatId = this.toChatId(formattedPhone);

    await this.greenApiPost('sendFileByUrl', {
      chatId,
      urlFile: mediaUrl,
      fileName: 'media-file',
      caption: caption || '',
    });
  }

  async logout(userId: string): Promise<void> {
    try {
      await this.greenApiPost('logout');
    } catch (e) {
      this.logger.warn(`⚠️ Green API logout warning: ${e.message}`);
    }
    this.setReadyState(userId, false, {
      needsReauth: true,
      lastError: 'Требуется авторизация в Green API',
      qrCode: null,
    });
  }

  async reconnect(userId: string): Promise<void> {
    await this.greenApiPost('reboot');
    await this.delay(2000);
    await this.refreshState(userId);
  }

  async destroy() {
    this.userStates.clear();
  }

  private async refreshState(userId: string): Promise<void> {
    try {
      const stateResponse = await this.greenApiGet('getStateInstance');
      const state = String(stateResponse?.stateInstance || '').toLowerCase();
      const ready = state === 'authorized';
      const current = this.userStates.get(userId) ?? this.getDefaultState();
      this.userStates.set(userId, {
        ...current,
        isReady: ready,
        needsReauth: !ready,
        lastError: ready
          ? null
          : `Инстанс не авторизован (${state || 'unknown'}).`,
      });
      if (!ready) {
        await this.tryRefreshQr(userId);
      }
    } catch (error) {
      const message = this.extractAxiosError(error);
      const current = this.userStates.get(userId) ?? this.getDefaultState();
      this.userStates.set(userId, {
        ...current,
        isReady: false,
        needsReauth: true,
        lastError: message,
      });
    }
  }

  private async tryRefreshQr(userId: string): Promise<void> {
    try {
      const qrResponse = await this.greenApiGet('qr');
      const qrCode = qrResponse?.qrCode || qrResponse?.message || null;
      const current = this.userStates.get(userId) ?? this.getDefaultState();
      this.userStates.set(userId, { ...current, qrCode });
    } catch (_) {
      const current = this.userStates.get(userId) ?? this.getDefaultState();
      this.userStates.set(userId, {
        ...current,
        qrCode: null,
        lastError:
          current.lastError ||
          `QR недоступен через API. Авторизуйте инстанс ${this.instanceName} в Green API.`,
      });
    }
  }

  private async greenApiPost(
    method: string,
    data?: Record<string, unknown>,
  ): Promise<any> {
    if (!this.apiTokenInstance) {
      throw new Error('GREEN_API_TOKEN_INSTANCE is not configured');
    }
    const url = `${this.apiUrl}/waInstance${this.idInstance}/${method}/${this.apiTokenInstance}`;
    const response = await axios.post(url, data || {}, { timeout: 60000 });
    return response.data;
  }

  private async greenApiGet(method: string): Promise<any> {
    if (!this.apiTokenInstance) {
      throw new Error('GREEN_API_TOKEN_INSTANCE is not configured');
    }
    const url = `${this.apiUrl}/waInstance${this.idInstance}/${method}/${this.apiTokenInstance}`;
    const response = await axios.get(url, { timeout: 60000 });
    return response.data;
  }

  private getDefaultState(): UserState {
    return {
      isReady: false,
      qrCode: null,
      needsReauth: true,
      lastError: null,
    };
  }

  private setReadyState(
    userId: string,
    isReady: boolean,
    patch?: Partial<UserState>,
  ): void {
    const current = this.userStates.get(userId) ?? this.getDefaultState();
    this.userStates.set(userId, {
      ...current,
      isReady,
      needsReauth: !isReady,
      ...(patch || {}),
    });
  }

  private toChatId(phone: string): string {
    return `${phone}@c.us`;
  }

  private formatPhoneNumber(phone: string): string {
    if (!phone || typeof phone !== 'string') {
      throw new Error('Номер телефона не указан или имеет неверный формат');
    }
    let cleaned = phone.replace(/\D/g, '');
    if (!cleaned) {
      throw new Error('Номер телефона не содержит цифр');
    }
    if (cleaned.startsWith('8') && cleaned.length === 11) {
      cleaned = `7${cleaned.substring(1)}`;
    }
    if (cleaned.length < 10 || cleaned.length > 15) {
      throw new Error(
        `Номер телефона имеет неверную длину: ${cleaned.length} цифр. Ожидается 10-15 цифр.`,
      );
    }
    return cleaned;
  }

  private extractAxiosError(error: unknown): string {
    if (error instanceof AxiosError) {
      const status = error.response?.status;
      const data = error.response?.data;
      if (typeof data === 'string') {
        return status ? `${status}: ${data}` : data;
      }
      if (data && typeof data === 'object') {
        const msg = (data as any).message || (data as any).error;
        if (msg) {
          return status ? `${status}: ${msg}` : String(msg);
        }
      }
      return status ? `${status}: ${error.message}` : error.message;
    }
    return String(error);
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
