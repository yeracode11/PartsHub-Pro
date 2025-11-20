import { Injectable, Logger, OnModuleInit, Inject } from '@nestjs/common';
import { Client, LocalAuth, Message } from 'whatsapp-web.js';
import * as qrcode from 'qrcode-terminal';
import { MessageHistoryService } from './message-history.service';
import { MessageStatus } from './entities/message-history.entity';
import { VehiclesService } from '../vehicles/vehicles.service';

@Injectable()
export class WhatsAppService implements OnModuleInit {
  private client: Client;
  private readonly logger = new Logger(WhatsAppService.name);
  private isReady = false;
  private qrCode: string | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 3;

  constructor(
    @Inject(MessageHistoryService)
    private readonly historyService: MessageHistoryService,
    private readonly vehiclesService: VehiclesService,
  ) {}

  async onModuleInit() {
    // Проверяем, нужно ли инициализировать WhatsApp
    const enableWhatsApp = process.env.ENABLE_WHATSAPP !== 'false';
    
    if (!enableWhatsApp) {
      this.logger.warn('⚠️ WhatsApp отключен (ENABLE_WHATSAPP=false)');
      this.logger.warn('💡 Для включения установите ENABLE_WHATSAPP=true');
      return;
    }

    this.logger.log('📱 Запуск инициализации WhatsApp в фоне...');
    // Запускаем в фоне с таймаутом, не дожидаясь результата
    setImmediate(async () => {
      try {
        // Таймаут 30 секунд для инициализации
        const timeoutPromise = new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Превышен таймаут инициализации (30 сек)')), 30000)
        );
        
        await Promise.race([
          this.initialize(),
          timeoutPromise
        ]);
      } catch (error) {
        this.logger.error(`❌ WhatsApp не удалось инициализировать: ${error.message}`);
        this.logger.warn('💡 Приложение продолжит работу без WhatsApp');
        this.isReady = false;
      }
    });
  }

  async initialize() {
    this.logger.log('📱 Инициализация WhatsApp клиента...');

    try {
      await this.initializeClient();
    } catch (error) {
      this.logger.error(`⚠️ Ошибка инициализации WhatsApp: ${error.message}`);
      this.logger.error(`📋 Stack trace: ${error.stack}`);
      this.isReady = false;
      throw error;
    }
  }

  private async initializeClient() {
    this.client = new Client({
      authStrategy: new LocalAuth({
        dataPath: '.wwebjs_auth', // Папка для хранения сессии
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
        timeout: 60000, // 60 секунд таймаут
      },
      webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
      },
    });

    // QR код для первой авторизации
    this.client.on('qr', (qr) => {
      this.qrCode = qr;
      this.logger.log('📲 Отсканируйте QR код в WhatsApp:');
      qrcode.generate(qr, { small: true });
      this.logger.log(`QR код сохранен, доступен через GET /api/whatsapp/qr`);
    });

    // Клиент готов
    this.client.on('ready', () => {
      this.isReady = true;
      this.qrCode = null;
      this.reconnectAttempts = 0; // Сбрасываем счетчик переподключений
      this.logger.log('✅ WhatsApp клиент готов к работе!');
    });

    // Авторизация прошла успешно
    this.client.on('authenticated', () => {
      this.logger.log('✅ WhatsApp авторизован');
    });

    // Ошибка авторизации
    this.client.on('auth_failure', (msg) => {
      this.logger.error('❌ Ошибка авторизации WhatsApp:', msg);
      this.isReady = false;
    });

    // Отключение
    this.client.on('disconnected', (reason) => {
      this.logger.warn('⚠️ WhatsApp отключен:', reason);
      this.isReady = false;
      this.qrCode = null;
      
      // Попытка переподключения
      if (this.reconnectAttempts < this.maxReconnectAttempts) {
        this.reconnectAttempts++;
        this.logger.log(`🔄 Попытка переподключения ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
        setTimeout(() => {
          this.initialize().catch(err => {
            this.logger.error('❌ Ошибка переподключения:', err.message);
          });
        }, 5000); // Ждем 5 секунд перед переподключением
      } else {
        this.logger.error('❌ Превышено максимальное количество попыток переподключения');
      }
    });

    // Входящие сообщения (для будущего функционала)
    this.client.on('message', async (message: Message) => {
      this.logger.debug(`📨 Получено сообщение от ${message.from}: ${message.body}`);
    });

    await this.client.initialize();
  }

  /**
   * Проверка готовности клиента
   */
  isClientReady(): boolean {
    return this.isReady;
  }

  /**
   * Получить QR код для авторизации
   */
  getQRCode(): string | null {
    return this.qrCode;
  }

  /**
   * Отправить сообщение одному контакту
   */
  async sendMessage(phone: string, message: string): Promise<void> {
    if (!this.isReady) {
      throw new Error('WhatsApp клиент не готов. Отсканируйте QR код.');
    }

    try {
      // Проверяем, что клиент все еще активен
      if (!this.client || !this.isReady) {
        throw new Error('WhatsApp клиент недоступен. Попробуйте переподключиться.');
      }

      // Форматируем номер телефона
      const formattedPhone = this.formatPhoneNumber(phone);
      const chatId = `${formattedPhone}@c.us`;

      this.logger.log(`📤 Отправка сообщения на ${formattedPhone}`);
      
      // Добавляем таймаут для отправки сообщения
      const sendPromise = this.client.sendMessage(chatId, message);
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Таймаут отправки сообщения (30 сек)')), 30000)
      );
      
      await Promise.race([sendPromise, timeoutPromise]);
      this.logger.log(`✅ Сообщение отправлено на ${formattedPhone}`);
    } catch (error) {
      this.logger.error(`❌ Ошибка отправки на ${phone}:`, error.message);
      
      // Если ошибка связана с сессией, помечаем клиент как неготовый
      if (error.message.includes('Session closed') || 
          error.message.includes('Protocol error') ||
          error.message.includes('Target closed')) {
        this.isReady = false;
        this.logger.warn('🔄 Сессия WhatsApp закрыта, требуется переподключение');
      }
      
      throw new Error(`Не удалось отправить сообщение: ${error.message}`);
    }
  }

  /**
   * Массовая рассылка с задержкой между сообщениями
   */
  async sendBulk(
    recipients: Array<{ phone: string; name?: string; customerId?: number }>,
    template: string,
    delayMs: number = 5000,
    options?: {
      organizationId: string;
      sentBy: string;
      campaignName?: string;
    },
  ): Promise<{ sent: number; failed: number; errors: string[] }> {
    if (!this.isReady) {
      throw new Error('WhatsApp клиент не готов');
    }

    const results = {
      sent: 0,
      failed: 0,
      errors: [] as string[],
    };

    this.logger.log(`📢 Начинаем массовую рассылку на ${recipients.length} контактов`);

    for (const recipient of recipients) {
      let status = MessageStatus.SENT;
      let errorMessage = null;

      try {
        // Получаем автомобиль клиента для замены {carModel}
        let carModelText = 'автомобиль';
        if (recipient.customerId && options?.organizationId) {
          try {
            const vehicles = await this.vehiclesService.findByCustomer(
              options.organizationId,
              recipient.customerId,
            );
            
            if (vehicles && vehicles.length > 0) {
              // Берем первый автомобиль клиента
              const vehicle = vehicles[0];
              // Формируем строку: "Toyota Camry 2020" или "Toyota Camry" если нет года
              carModelText = vehicle.year
                ? `${vehicle.brand} ${vehicle.model} ${vehicle.year}`
                : `${vehicle.brand} ${vehicle.model}`;
            }
          } catch (e) {
            this.logger.warn(`Не удалось получить автомобиль для клиента ${recipient.customerId}: ${e.message}`);
          }
        }

        // Подставляем переменные в шаблон
        let personalizedMessage = template.replace(
          '{name}',
          recipient.name || 'Уважаемый клиент',
        );
        personalizedMessage = personalizedMessage.replace(
          '{carModel}',
          carModelText,
        );
        
        // Заменяем {organizationName} если есть
        if (options?.organizationId) {
          // Можно добавить получение названия организации, если нужно
          personalizedMessage = personalizedMessage.replace(
            '{organizationName}',
            'наш сервис',
          );
        }

        await this.sendMessage(recipient.phone, personalizedMessage);
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
          // Получаем автомобиль для истории тоже
          let carModelText = 'автомобиль';
          if (recipient.customerId) {
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

          let historyMessage = template.replace(
            '{name}',
            recipient.name || 'Уважаемый клиент',
          );
          historyMessage = historyMessage.replace('{carModel}', carModelText);
          historyMessage = historyMessage.replace('{organizationName}', 'наш сервис');

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

      // Задержка между отправками (чтобы не попасть в бан)
      if (delayMs > 0) {
        await this.delay(delayMs);
      }
    }

    this.logger.log(
      `✅ Рассылка завершена. Отправлено: ${results.sent}, Ошибок: ${results.failed}`,
    );

    return results;
  }

  /**
   * Отправить сообщение с медиа (изображение, PDF)
   * Примечание: для полноценной работы нужно установить MessageMedia из whatsapp-web.js
   */
  async sendMediaMessage(
    phone: string,
    mediaUrl: string,
    caption?: string,
  ): Promise<void> {
    if (!this.isReady) {
      throw new Error('WhatsApp клиент не готов');
    }

    try {
      const formattedPhone = this.formatPhoneNumber(phone);
      const chatId = `${formattedPhone}@c.us`;

      // Пока просто отправляем текст с ссылкой
      // TODO: Реализовать отправку медиа через MessageMedia.fromUrl()
      const message = caption
        ? `${caption}\n\n${mediaUrl}`
        : mediaUrl;

      await this.client.sendMessage(chatId, message);

      this.logger.log(`✅ Сообщение с медиа отправлено на ${formattedPhone}`);
    } catch (error) {
      this.logger.error(`❌ Ошибка отправки медиа на ${phone}:`, error.message);
      throw error;
    }
  }

  /**
   * Форматирование номера телефона
   * +77771234567 -> 77771234567
   */
  private formatPhoneNumber(phone: string): string {
    // Удаляем все символы кроме цифр
    let cleaned = phone.replace(/\D/g, '');

    // Если начинается с 8, заменяем на 7
    if (cleaned.startsWith('8')) {
      cleaned = '7' + cleaned.substring(1);
    }

    // Убираем начальный + если есть
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
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
   * Принудительное переподключение
   */
  async reconnect(): Promise<void> {
    this.logger.log('🔄 Принудительное переподключение WhatsApp...');
    
    try {
      // Останавливаем текущий клиент
      if (this.client) {
        await this.client.destroy();
      }
      
      // Сбрасываем состояние
      this.isReady = false;
      this.qrCode = null;
      this.reconnectAttempts = 0;
      
      // Переинициализируем
      await this.initialize();
      this.logger.log('✅ WhatsApp переподключен');
    } catch (error) {
      this.logger.error('❌ Ошибка переподключения:', error.message);
      throw error;
    }
  }

  /**
   * Остановка клиента
   */
  async destroy() {
    if (this.client) {
      await this.client.destroy();
      this.logger.log('WhatsApp клиент остановлен');
    }
  }
}

