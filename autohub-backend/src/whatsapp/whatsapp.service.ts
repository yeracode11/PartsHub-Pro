import { Injectable, Logger, OnModuleInit, Inject } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { GreenApiClient } from '@green-api/whatsapp-api-client-js-v2';
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

  /** apiUrl из личного кабинета Green API (https://api.green-api.com или https://XXXX.api.greenapi.com) */
  private readonly apiUrl =
    process.env.GREEN_API_URL || 'https://api.green-api.com';
  private readonly idInstance =
    process.env.GREEN_API_ID_INSTANCE || '7105313983';
  private readonly apiTokenInstance = process.env.GREEN_API_TOKEN_INSTANCE || '';
  private readonly instanceName =
    process.env.GREEN_API_INSTANCE_NAME || this.idInstance;

  /** Green API SDK client с поддержкой кастомного apiUrl (для кластера 7105) */
  private get greenClient(): GreenApiClient {
    const id = parseInt(String(this.idInstance), 10);
    const client = new GreenApiClient({
      idInstance: id,
      apiTokenInstance: this.apiTokenInstance,
    });
    if (this.apiUrl) {
      const base = this.apiUrl.replace(/\/$/, '');
      (client as any).client = axios.create({
        baseURL: `${base}/waInstance${this.idInstance}`,
        timeout: 60000,
      });
    }
    return client;
  }

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

  /** Прямая ссылка на QR для браузера (qr.green-api.com) */
  getQRUrl(): string | null {
    if (!this.apiTokenInstance || !this.idInstance) return null;
    return `https://qr.green-api.com/waInstance${this.idInstance}/${this.apiTokenInstance}`;
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

    const formattedPhone = this.formatPhoneNumber(phone);
    const chatId = this.toChatId(formattedPhone);
    const client = this.greenClient;

    // Если инстанс уже авторизован — отправляем сразу (как в примерах SDK)
    if (this.isClientReady(userId)) {
      try {
        await client.sendMessage({
          chatId,
          message,
          linkPreview: false,
        });
        return;
      } catch (error) {
        const msg = String((error as Error).message || '').toLowerCase();
        if (
          msg.includes('401') ||
          msg.includes('404') ||
          msg.includes('unauthorized') ||
          msg.includes('not authorized') ||
          msg.includes('not logged')
        ) {
          this.setReadyState(userId, false, {
            needsReauth: true,
            lastError: 'Инстанс Green API не авторизован или неверный URL.',
          });
        }
        throw error;
      }
    }

    // Иначе проверяем статус и при необходимости показываем QR
    await this.refreshState(userId);
    if (!this.isClientReady(userId)) {
      throw new Error(
        'WhatsApp не готов в Green API. Выполните авторизацию инстанса (отсканируйте QR в личном кабинете или по ссылке).',
      );
    }

    let lastError: Error | null = null;
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await client.sendMessage({
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

    await this.greenClient.sendFileByUrl({
      chatId,
      file: { url: mediaUrl, fileName: 'media-file' },
      caption: caption || '',
    });
  }

  /**
   * Разлогинивание инстанса (GET {{apiUrl}}/waInstance{{idInstance}}/logout/{{apiTokenInstance}})
   */
  async logout(userId: string): Promise<void> {
    if (!this.apiTokenInstance) {
      this.setReadyState(userId, false, {
        needsReauth: true,
        lastError: 'GREEN_API_TOKEN_INSTANCE не задан',
        qrCode: null,
      });
      return;
    }

    const base = this.apiUrl.replace(/\/$/, '');
    const url = `${base}/waInstance${this.idInstance}/logout/${this.apiTokenInstance}`;

    try {
      const { data } = await axios.get<{ isLogout?: boolean }>(url, {
        timeout: 15000,
      });
      if (data?.isLogout !== true) {
        this.logger.warn(`Green API logout: неожиданный ответ ${JSON.stringify(data)}`);
      }
    } catch (e: any) {
      const msg = e?.response?.data?.message || e?.message || String(e);
      this.logger.warn(`⚠️ Green API logout: ${msg}`);
      throw new Error(`Не удалось выйти из WhatsApp: ${msg}`);
    }

    this.setReadyState(userId, false, {
      needsReauth: true,
      lastError: 'Требуется авторизация в Green API',
      qrCode: null,
    });
  }

  async reconnect(userId: string): Promise<void> {
    if (!this.apiTokenInstance) {
      const current = this.userStates.get(userId) ?? this.getDefaultState();
      this.userStates.set(userId, {
        ...current,
        isReady: false,
        needsReauth: true,
        qrCode: null,
        lastError: 'GREEN_API_TOKEN_INSTANCE не задан. Добавьте токен в .env',
      });
      return;
    }

    const current = this.userStates.get(userId) ?? this.getDefaultState();
    const client = this.greenClient;

    // 1. Проверяем состояние инстанса (если 404 — неверный GREEN_API_URL)
    let state: string | null = null;
    try {
      const stateRes = await client.getStateInstance();
      state = String(stateRes?.stateInstance || '').toLowerCase();
    } catch (e: any) {
      const errMsg = e?.message || String(e);
      const status = e?.response?.status ?? (e?.cause as any)?.response?.status;
      const is404 =
        String(errMsg).includes('404') || status === 404;
      if (is404) {
        this.userStates.set(userId, {
          ...current,
          isReady: false,
          needsReauth: true,
          qrCode: null,
          lastError: `Green API вернул 404. Проверьте GREEN_API_URL в .env — он должен совпадать с apiUrl из личного кабинета (https://console.green-api.com). Для кластера 7105: https://7105.api.greenapi.com`,
        });
        return;
      }
      this.logger.warn(`Reconnect getStateInstance: ${errMsg}`);
    }

    // 2. Если авторизован — делаем logout, затем получаем QR
    if (state === 'authorized') {
      try {
        await client.logout();
        await this.delay(3000);
      } catch (e: any) {
        this.logger.warn(`Reconnect logout (игнорируем): ${e?.message || e}`);
      }
    }

    // 3. Обновляем статус и получаем QR
    try {
      await this.refreshState(userId);
    } catch (_) {}
    await this.tryRefreshQr(userId);
  }

  async destroy() {
    this.userStates.clear();
  }

  private async refreshState(userId: string): Promise<void> {
    if (!this.apiTokenInstance) {
      const current = this.userStates.get(userId) ?? this.getDefaultState();
      this.userStates.set(userId, {
        ...current,
        isReady: false,
        needsReauth: true,
        lastError: 'GREEN_API_TOKEN_INSTANCE не задан. Добавьте токен в .env',
      });
      await this.tryRefreshQr(userId);
      return;
    }

    try {
      const stateResponse = await this.greenClient.getStateInstance();
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
      // При ошибке getStateInstance пробуем получить QR (fallback через qr.green-api.com)
      try {
        await this.tryRefreshQr(userId);
      } catch (_) {
        // Игнорируем — QR может быть недоступен
      }
    }
  }

  private async tryRefreshQr(userId: string): Promise<void> {
    const current = this.userStates.get(userId) ?? this.getDefaultState();

    if (!this.apiTokenInstance) {
      this.userStates.set(userId, {
        ...current,
        qrCode: null,
        lastError:
          current.lastError ||
          'GREEN_API_TOKEN_INSTANCE не задан. Добавьте токен в .env',
      });
      return;
    }

    try {
      const client = this.greenClient;
      let qrResponse = await client.getQR();
      const type = String(qrResponse?.type || '').toLowerCase();

      if (type === 'alreadylogged') {
        this.logger.warn('QR: инстанс авторизован, выполняем Logout...');
        try {
          await client.logout();
          await this.delay(3000);
          qrResponse = await client.getQR();
        } catch (_) {}
      }

      let qrCode: string | null = null;
      if (qrResponse?.type === 'qrCode' && qrResponse?.message) {
        qrCode = qrResponse.message.startsWith('data:')
          ? qrResponse.message
          : `data:image/png;base64,${qrResponse.message}`;
      }

      if (qrCode) {
        this.userStates.set(userId, { ...current, qrCode });
        return;
      }
    } catch (_) {
      // API вернул ошибку
    }

    // 2. qrUrl для браузера — всегда доступна. API возвращает QR только когда инстанс не авторизован.
    this.userStates.set(userId, {
      ...current,
      qrCode: null,
      lastError:
        current.lastError ||
        `QR через API недоступен (инстанс может быть авторизован). Нажмите «Переподключить» или откройте ссылку в браузере.`,
    });
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
