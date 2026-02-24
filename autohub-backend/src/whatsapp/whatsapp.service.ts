import { Injectable, Logger, OnModuleInit, Inject } from '@nestjs/common';
import { Client, LocalAuth, Message } from 'whatsapp-web.js';
import * as qrcode from 'qrcode-terminal';
import { MessageHistoryService } from './message-history.service';
import { MessageStatus } from './entities/message-history.entity';
import { VehiclesService } from '../vehicles/vehicles.service';
import { TemplatesService } from './templates.service';
import * as fs from 'fs';
import * as path from 'path';

interface UserSession {
  client: Client;
  isReady: boolean;
  qrCode: string | null;
  reconnectAttempts: number;
  isInitializing: boolean;
  needsReauth: boolean;
  reconnectInProgress: boolean;
  reauthInProgress: boolean;
  userId: string;
}

@Injectable()
export class WhatsAppService implements OnModuleInit {
  private readonly logger = new Logger(WhatsAppService.name);
  private userSessions: Map<string, UserSession> = new Map();
  private readonly maxReconnectAttempts = 3;

  constructor(
    @Inject(MessageHistoryService)
    private readonly historyService: MessageHistoryService,
    private readonly vehiclesService: VehiclesService,
    private readonly templatesService: TemplatesService,
  ) {}

  async onModuleInit() {
    // WhatsApp теперь инициализируется по требованию для каждого пользователя
    this.logger.log('📱 WhatsApp сервис готов. Сессии будут создаваться по требованию.');
  }

  /**
   * Получить или создать сессию для пользователя
   */
  private async getOrCreateSession(userId: string): Promise<UserSession> {
    let session = this.userSessions.get(userId);

    if (!session) {
      this.logger.log(`📱 Создание новой WhatsApp сессии для пользователя: ${userId}`);
      session = await this.createSession(userId);
      this.userSessions.set(userId, session);
    }

    return session;
  }

  /**
   * Создать новую сессию для пользователя
   */
  private async createSession(userId: string): Promise<UserSession> {
    const dataPath = path.join('.wwebjs_auth', userId);
    
    // Создаем директорию для сессии, если её нет
    if (!fs.existsSync(dataPath)) {
      fs.mkdirSync(dataPath, { recursive: true });
    }

    const client = new Client({
      authStrategy: new LocalAuth({
        dataPath: dataPath,
      }),
      puppeteer: {
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--no-first-run',
          '--no-zygote',
          '--disable-gpu',
          '--disable-web-security',
          '--disable-features=VizDisplayCompositor',
          '--disable-extensions',
          '--disable-plugins',
          '--disable-images',
          '--disable-javascript',
          '--disable-default-apps',
          '--disable-background-timer-throttling',
          '--disable-backgrounding-occluded-windows',
          '--disable-renderer-backgrounding',
        ],
        timeout: 120000,
      },
      webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
      },
    });

    const session: UserSession = {
      client,
      isReady: false,
      qrCode: null,
      reconnectAttempts: 0,
      isInitializing: true,
      needsReauth: false,
      reconnectInProgress: false,
      reauthInProgress: false,
      userId,
    };

    // QR код для первой авторизации
    client.on('qr', (qr) => {
      session.qrCode = qr;
      session.needsReauth = true;
      session.isInitializing = false;
      this.logger.log(`📲 QR код для пользователя ${userId}:`);
      qrcode.generate(qr, { small: true });
    });

    // Клиент готов
    client.on('ready', () => {
      session.isReady = true;
      session.qrCode = null;
      session.reconnectAttempts = 0;
      session.needsReauth = false;
      session.isInitializing = false;
      this.logger.log(`✅ WhatsApp клиент готов для пользователя ${userId}!`);
    });

    // Авторизация прошла успешно
    client.on('authenticated', () => {
      session.isInitializing = false;
      this.logger.log(`✅ WhatsApp авторизован для пользователя ${userId}`);
    });

    // Ошибка авторизации
    client.on('auth_failure', (msg) => {
      this.logger.error(`❌ Ошибка авторизации WhatsApp для пользователя ${userId}:`, msg);
      session.isReady = false;
      session.needsReauth = true;
      session.qrCode = null;
      this.scheduleReauth(userId, 'auth_failure').catch(() => undefined);
    });

    // Отключение
    client.on('disconnected', (reason) => {
      this.logger.warn(`⚠️ WhatsApp отключен для пользователя ${userId}:`, reason);
      session.isReady = false;
      session.qrCode = null;
      
      // Попытка переподключения
      if (session.reconnectAttempts < this.maxReconnectAttempts) {
        session.reconnectAttempts++;
        this.logger.log(`🔄 Попытка переподключения ${session.reconnectAttempts}/${this.maxReconnectAttempts} для пользователя ${userId}`);
        this.scheduleReconnect(userId).catch(() => undefined);
      } else {
        this.logger.error(`❌ Превышено максимальное количество попыток переподключения для пользователя ${userId}`);
        this.scheduleReauth(userId, 'max_reconnect_attempts').catch(() => undefined);
      }
    });

    // Входящие сообщения
    client.on('message', async (message: Message) => {
      this.logger.debug(`📨 Получено сообщение от ${message.from} для пользователя ${userId}: ${message.body}`);
    });

    // Инициализируем клиент
    await client.initialize();

    return session;
  }

  /**
   * Инициализировать сессию пользователя
   */
  async initializeUserSession(userId: string): Promise<void> {
    this.logger.log(`📱 Инициализация WhatsApp сессии для пользователя: ${userId}`);
    const session = await this.getOrCreateSession(userId);
    if (session.isInitializing) {
      return;
    }
    // Сессия уже создана и инициализирована в createSession
  }

  /**
   * Проверка готовности клиента пользователя
   */
  isClientReady(userId: string): boolean {
    const session = this.userSessions.get(userId);
    return session?.isReady || false;
  }

  /**
   * Получить QR код для авторизации пользователя
   */
  getQRCode(userId: string): string | null {
    const session = this.userSessions.get(userId);
    return session?.qrCode || null;
  }

  /**
   * Нужна повторная авторизация через QR
   */
  needsReauth(userId: string): boolean {
    const session = this.userSessions.get(userId);
    return session?.needsReauth || false;
  }

  /**
   * Принудительная повторная авторизация (очищает сессию)
   */
  async forceReauth(userId: string, reason: string = 'manual'): Promise<void> {
    this.logger.warn(`🔐 Принудительная повторная авторизация WhatsApp (${reason}) для пользователя ${userId}`);
    await this.rebuildSession(userId, true);
  }

  /**
   * Отправить сообщение одному контакту с retry логикой
   */
  async sendMessage(
    userId: string,
    phone: string,
    message: string,
    retries: number = 3,
  ): Promise<void> {
    const session = await this.getOrCreateSession(userId);

    if (!session.client) {
      this.logger.error(`❌ WhatsApp клиент не инициализирован для пользователя ${userId}`);
      throw new Error('WhatsApp клиент не инициализирован. Попробуйте переподключиться.');
    }

    if (!session.isReady) {
      this.logger.error(`❌ WhatsApp клиент не готов для пользователя ${userId}. isReady = false`);
      throw new Error('WhatsApp клиент не готов. Отсканируйте QR код.');
    }

    // Проверяем состояние клиента через API
    try {
      const state = await session.client.getState();
      this.logger.log(`📊 Состояние WhatsApp клиента для пользователя ${userId}: ${state}`);
      
      if (state !== 'CONNECTED') {
        this.logger.warn(`⚠️ WhatsApp клиент не подключен для пользователя ${userId}. Состояние: ${state}`);
        session.isReady = false;
        session.needsReauth = true;
        this.scheduleReauth(userId, 'state_not_connected').catch(() => undefined);
        throw new Error(`WhatsApp клиент не подключен. Состояние: ${state}. Требуется переподключение.`);
      }
    } catch (stateError) {
      this.logger.error(`❌ Ошибка проверки состояния клиента для пользователя ${userId}: ${stateError.message}`);
    }

    // Форматируем номер телефона
    const formattedPhone = this.formatPhoneNumber(phone);
    const chatId = `${formattedPhone}@c.us`;

    this.logger.log(`📱 Отправка на номер: ${phone} -> ${formattedPhone} (chatId: ${chatId}) для пользователя ${userId}`);
    this.logger.log(`📝 Длина сообщения: ${message.length} символов`);

    let lastError: Error | null = null;

    // Retry логика
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        this.logger.log(
          `📤 Отправка сообщения на ${formattedPhone} (попытка ${attempt}/${retries}) для пользователя ${userId}`,
        );

        if (!session.isReady || !session.client) {
          throw new Error('WhatsApp клиент стал недоступен');
        }

        const sendPromise = session.client.sendMessage(chatId, message);
        const timeoutPromise = new Promise<never>((_, reject) =>
          setTimeout(
            () =>
              reject(
                new Error(
                  `Таймаут отправки сообщения (90 сек, попытка ${attempt}/${retries})`,
                ),
              ),
            90000,
          ),
        );

        const result = await Promise.race([sendPromise, timeoutPromise]);
        
        if (result) {
          this.logger.log(`✅ Сообщение отправлено на ${formattedPhone}. ID: ${result.id || 'N/A'} для пользователя ${userId}`);
        } else {
          this.logger.log(`✅ Сообщение отправлено на ${formattedPhone} для пользователя ${userId}`);
        }
        
        return;
      } catch (error) {
        lastError = error as Error;
        const errorMessage = error.message || 'Неизвестная ошибка';

        this.logger.error(
          `❌ Попытка ${attempt}/${retries} не удалась для ${formattedPhone} (пользователь ${userId})`,
        );
        this.logger.error(`   Ошибка: ${errorMessage}`);

        const errorLower = errorMessage.toLowerCase();

        if (
          errorLower.includes('session closed') ||
          errorLower.includes('protocol error') ||
          errorLower.includes('target closed') ||
          errorLower.includes('не готов') ||
          errorLower.includes('недоступен') ||
          errorLower.includes('not connected') ||
          errorLower.includes('disconnected') ||
          errorLower.includes('authentication') ||
          errorLower.includes('auth_failure')
        ) {
          session.isReady = false;
          this.logger.warn(
            `🔄 Сессия WhatsApp закрыта для пользователя ${userId}, требуется переподключение`,
          );
          throw new Error(
            `Не удалось отправить сообщение: ${errorMessage}. Требуется переподключение WhatsApp.`,
          );
        }

        if (
          errorLower.includes('invalid number') ||
          errorLower.includes('неверный номер') ||
          errorLower.includes('number not registered') ||
          errorLower.includes('номер не зарегистрирован')
        ) {
          throw new Error(`Неверный номер телефона: ${errorMessage}`);
        }

        if (
          errorLower.includes('blocked') ||
          errorLower.includes('заблокирован') ||
          errorLower.includes('rate limit') ||
          errorLower.includes('too many requests')
        ) {
          throw new Error(
            `Сообщение не может быть отправлено: ${errorMessage}. Возможно, номер заблокирован или превышен лимит запросов.`,
          );
        }

        if (attempt < retries) {
          const delayMs = attempt * 3000;
          this.logger.log(`⏳ Ожидание ${delayMs}мс перед повторной попыткой...`);
          await this.delay(delayMs);

          if (!session.isReady || !session.client) {
            throw new Error('WhatsApp клиент стал недоступен во время повторных попыток');
          }

          try {
            const state = await session.client.getState();
            if (state !== 'CONNECTED') {
              this.logger.warn(`⚠️ Состояние клиента изменилось для пользователя ${userId}: ${state}`);
              session.isReady = false;
              throw new Error(`WhatsApp клиент отключен. Состояние: ${state}`);
            }
          } catch (stateError) {
            this.logger.warn(`⚠️ Не удалось проверить состояние для пользователя ${userId}: ${stateError.message}`);
          }
        }
      }
    }

    this.logger.error(
      `❌ Не удалось отправить сообщение на ${formattedPhone} после ${retries} попыток (пользователь ${userId})`,
    );
    this.logger.error(`   Последняя ошибка: ${lastError?.message}`);
    
    throw new Error(
      `Не удалось отправить сообщение после ${retries} попыток: ${lastError?.message}`,
    );
  }

  /**
   * Массовая рассылка с задержкой между сообщениями
   */
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
    const session = await this.getOrCreateSession(userId);
    
    if (!session.isReady) {
      throw new Error('WhatsApp клиент не готов');
    }

    const results = {
      sent: 0,
      failed: 0,
      errors: [] as string[],
    };

    this.logger.log(`📢 Начинаем массовую рассылку на ${recipients.length} контактов для пользователя ${userId}`);

    for (const recipient of recipients) {
      let status = MessageStatus.SENT;
      let errorMessage = null;

      try {
        // Получаем автомобиль клиента для замены {carModel}
        let carModelText = 'автомобиль';
        
        if (recipient.customerId && options?.organizationId) {
          try {
            const customerId = typeof recipient.customerId === 'number' 
              ? recipient.customerId 
              : parseInt(String(recipient.customerId), 10);
            
            if (!isNaN(customerId)) {
              const vehicles = await this.vehiclesService.findByCustomer(
                options.organizationId,
                customerId,
              );
              
              if (vehicles && vehicles.length > 0) {
                const vehicle = vehicles[0];
                carModelText = vehicle.year
                  ? `${vehicle.brand} ${vehicle.model} ${vehicle.year}`
                  : `${vehicle.brand} ${vehicle.model}`;
              }
            }
          } catch (e) {
            this.logger.error(`❌ Ошибка получения автомобиля для клиента ${recipient.customerId}: ${e.message}`);
          }
        }

        // Подставляем переменные в шаблон
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

      // Сохраняем в историю
      if (options) {
        try {
          let carModelText = 'автомобиль';
          if (recipient.customerId && options?.organizationId) {
            try {
              const vehicles = await this.vehiclesService.findByCustomer(
                options.organizationId,
                recipient.customerId,
              );
              
              if (vehicles && vehicles.length > 0) {
                const vehicle = vehicles[0];
                carModelText = vehicle.year
                  ? `${vehicle.brand} ${vehicle.model} ${vehicle.year}`
                  : `${vehicle.brand} ${vehicle.model}`;
              }
            } catch (e) {
              // Игнорируем ошибку при сохранении истории
            }
          }

          const historyVariables: Record<string, string> = {
            name: recipient.name || 'Уважаемый клиент',
            carModel: carModelText,
          };
          
          if (options?.organizationId) {
            historyVariables.organizationName = 'наш сервис';
          }
          
          const historyMessage = this.templatesService.fillTemplate(
            template,
            historyVariables,
          );

          await this.historyService.create({
            organizationId: options.organizationId,
            sentBy: options.sentBy,
            customerId: recipient.customerId,
            phone: recipient.phone,
            message: historyMessage,
            status,
            errorMessage,
            isBulk: true,
            campaignName: options.campaignName,
          });
        } catch (e) {
          this.logger.error(`Ошибка сохранения истории: ${e.message}`);
        }
      }

      if (delayMs > 0) {
        await this.delay(delayMs);
      }
    }

    this.logger.log(
      `✅ Рассылка завершена для пользователя ${userId}. Отправлено: ${results.sent}, Ошибок: ${results.failed}`,
    );

    return results;
  }

  /**
   * Отправить сообщение с медиа
   */
  async sendMediaMessage(
    userId: string,
    phone: string,
    mediaUrl: string,
    caption?: string,
  ): Promise<void> {
    const session = await this.getOrCreateSession(userId);
    
    if (!session.isReady) {
      throw new Error('WhatsApp клиент не готов');
    }

    try {
      const formattedPhone = this.formatPhoneNumber(phone);
      const chatId = `${formattedPhone}@c.us`;

      const message = caption
        ? `${caption}\n\n${mediaUrl}`
        : mediaUrl;

      await session.client.sendMessage(chatId, message);

      this.logger.log(`✅ Сообщение с медиа отправлено на ${formattedPhone} для пользователя ${userId}`);
    } catch (error) {
      this.logger.error(`❌ Ошибка отправки медиа на ${phone} для пользователя ${userId}:`, error.message);
      throw error;
    }
  }

  /**
   * Выйти из WhatsApp аккаунта (удалить сессию)
   */
  async logout(userId: string): Promise<void> {
    this.logger.log(`🚪 Выход из WhatsApp для пользователя ${userId}`);
    
    const session = this.userSessions.get(userId);
    
    if (session) {
      try {
        // Уничтожаем клиент
        if (session.client) {
          await session.client.destroy();
        }
        
        // Удаляем сессию из памяти
        this.userSessions.delete(userId);
        
        // Удаляем директорию с сессией
        const dataPath = path.join('.wwebjs_auth', userId);
        if (fs.existsSync(dataPath)) {
          fs.rmSync(dataPath, { recursive: true, force: true });
          this.logger.log(`🗑️ Удалена директория сессии для пользователя ${userId}`);
        }
        
        this.logger.log(`✅ Пользователь ${userId} успешно вышел из WhatsApp`);
      } catch (error) {
        this.logger.error(`❌ Ошибка при выходе из WhatsApp для пользователя ${userId}:`, error.message);
        throw error;
      }
    } else {
      this.logger.warn(`⚠️ Сессия не найдена для пользователя ${userId}`);
    }
  }

  /**
   * Принудительное переподключение
   */
  async reconnect(userId: string): Promise<void> {
    this.logger.log(`🔄 Принудительное переподключение WhatsApp для пользователя ${userId}...`);
    
    try {
      await this.rebuildSession(userId, false);
      
      this.logger.log(`✅ WhatsApp переподключен для пользователя ${userId}`);
    } catch (error) {
      this.logger.error(`❌ Ошибка переподключения для пользователя ${userId}:`, error.message);
      throw error;
    }
  }

  /**
   * Форматирование номера телефона
   */
  private formatPhoneNumber(phone: string): string {
    if (!phone || typeof phone !== 'string') {
      throw new Error('Номер телефона не указан или имеет неверный формат');
    }

    let cleaned = phone.replace(/\D/g, '');

    if (!cleaned || cleaned.length === 0) {
      throw new Error('Номер телефона не содержит цифр');
    }

    if (cleaned.startsWith('8') && cleaned.length === 11) {
      cleaned = '7' + cleaned.substring(1);
    }

    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.length < 10 || cleaned.length > 15) {
      throw new Error(
        `Номер телефона имеет неверную длину: ${cleaned.length} цифр. Ожидается 10-15 цифр.`,
      );
    }

    return cleaned;
  }

  /**
   * Задержка (утилита)
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Пересоздать сессию (с сохранением или очисткой авторизации)
   */
  private async rebuildSession(userId: string, clearAuth: boolean): Promise<void> {
    const existing = this.userSessions.get(userId);
    if (existing?.client) {
      try {
        await existing.client.destroy();
      } catch (e) {
        this.logger.warn(`⚠️ Не удалось корректно остановить клиента для ${userId}: ${e.message}`);
      }
    }

    if (clearAuth) {
      const dataPath = path.join('.wwebjs_auth', userId);
      if (fs.existsSync(dataPath)) {
        fs.rmSync(dataPath, { recursive: true, force: true });
      }
    }

    const session = await this.createSession(userId);
    if (clearAuth) {
      session.needsReauth = true;
    }
    this.userSessions.set(userId, session);
  }

  /**
   * Плановое переподключение без очистки авторизации
   */
  private async scheduleReconnect(userId: string): Promise<void> {
    const session = this.userSessions.get(userId);
    if (!session || session.reconnectInProgress) {
      return;
    }
    session.reconnectInProgress = true;
    setTimeout(async () => {
      try {
        await this.rebuildSession(userId, false);
      } catch (err) {
        this.logger.error(`❌ Ошибка переподключения для пользователя ${userId}:`, err.message);
      } finally {
        const updated = this.userSessions.get(userId);
        if (updated) {
          updated.reconnectInProgress = false;
        }
      }
    }, 5000);
  }

  /**
   * Плановая повторная авторизация через QR
   */
  private async scheduleReauth(userId: string, reason: string): Promise<void> {
    const session = this.userSessions.get(userId);
    if (!session || session.reauthInProgress) {
      return;
    }
    session.reauthInProgress = true;
    session.needsReauth = true;
    setTimeout(async () => {
      try {
        this.logger.warn(`🔐 Требуется повторная авторизация WhatsApp (${reason}) для пользователя ${userId}`);
        await this.rebuildSession(userId, true);
      } catch (err) {
        this.logger.error(`❌ Ошибка повторной авторизации для пользователя ${userId}:`, err.message);
      } finally {
        const updated = this.userSessions.get(userId);
        if (updated) {
          updated.reauthInProgress = false;
        }
      }
    }, 1000);
  }

  /**
   * Остановка всех клиентов
   */
  async destroy() {
    for (const [userId, session] of this.userSessions.entries()) {
      try {
        if (session.client) {
          await session.client.destroy();
        }
        this.logger.log(`WhatsApp клиент остановлен для пользователя ${userId}`);
      } catch (error) {
        this.logger.error(`Ошибка остановки клиента для пользователя ${userId}:`, error.message);
      }
    }
    this.userSessions.clear();
  }
}
