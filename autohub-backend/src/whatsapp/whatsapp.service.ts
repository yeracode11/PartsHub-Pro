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
        timeout: 120000, // 120 секунд таймаут для инициализации
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
   * Отправить сообщение одному контакту с retry логикой
   */
  async sendMessage(
    phone: string,
    message: string,
    retries: number = 3,
  ): Promise<void> {
    // Детальная проверка состояния клиента
    if (!this.client) {
      this.logger.error('❌ WhatsApp клиент не инициализирован');
      throw new Error('WhatsApp клиент не инициализирован. Попробуйте переподключиться.');
    }

    if (!this.isReady) {
      this.logger.error('❌ WhatsApp клиент не готов. isReady = false');
      throw new Error('WhatsApp клиент не готов. Отсканируйте QR код.');
    }

    // Проверяем состояние клиента через API
    try {
      const state = await this.client.getState();
      this.logger.log(`📊 Состояние WhatsApp клиента: ${state}`);
      
      if (state !== 'CONNECTED') {
        this.logger.warn(`⚠️ WhatsApp клиент не подключен. Состояние: ${state}`);
        this.isReady = false;
        throw new Error(`WhatsApp клиент не подключен. Состояние: ${state}. Требуется переподключение.`);
      }
    } catch (stateError) {
      this.logger.error(`❌ Ошибка проверки состояния клиента: ${stateError.message}`);
      // Продолжаем, если не можем проверить состояние
    }

    // Форматируем номер телефона
    const formattedPhone = this.formatPhoneNumber(phone);
    const chatId = `${formattedPhone}@c.us`;

    this.logger.log(`📱 Отправка на номер: ${phone} -> ${formattedPhone} (chatId: ${chatId})`);
    this.logger.log(`📝 Длина сообщения: ${message.length} символов`);

    let lastError: Error | null = null;

    // Retry логика
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        this.logger.log(
          `📤 Отправка сообщения на ${formattedPhone} (попытка ${attempt}/${retries})`,
        );

        // Проверяем состояние перед каждой попыткой
        if (!this.isReady || !this.client) {
          throw new Error('WhatsApp клиент стал недоступен');
        }

        // Увеличиваем таймаут до 90 секунд для WhatsApp Web.js
        const sendPromise = this.client.sendMessage(chatId, message);
        const timeoutPromise = new Promise<never>((_, reject) =>
          setTimeout(
            () =>
              reject(
                new Error(
                  `Таймаут отправки сообщения (90 сек, попытка ${attempt}/${retries})`,
                ),
              ),
            90000, // 90 секунд
          ),
        );

        const result = await Promise.race([sendPromise, timeoutPromise]);
        
        // Логируем результат отправки
        if (result) {
          this.logger.log(`✅ Сообщение отправлено на ${formattedPhone}. ID: ${result.id || 'N/A'}`);
        } else {
          this.logger.log(`✅ Сообщение отправлено на ${formattedPhone}`);
        }
        
        return; // Успешно отправлено, выходим из цикла
      } catch (error) {
        lastError = error as Error;
        const errorMessage = error.message || 'Неизвестная ошибка';
        const errorStack = error.stack || '';

        // Детальное логирование ошибки
        this.logger.error(
          `❌ Попытка ${attempt}/${retries} не удалась для ${formattedPhone}`,
        );
        this.logger.error(`   Ошибка: ${errorMessage}`);
        this.logger.error(`   Тип ошибки: ${error.constructor?.name || 'Unknown'}`);
        if (errorStack) {
          this.logger.error(`   Stack: ${errorStack.substring(0, 500)}`);
        }

        // Проверяем различные типы ошибок
        const errorLower = errorMessage.toLowerCase();

        // Ошибки, связанные с сессией - не повторяем
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
          this.isReady = false;
          this.logger.warn(
            '🔄 Сессия WhatsApp закрыта, требуется переподключение',
          );
          throw new Error(
            `Не удалось отправить сообщение: ${errorMessage}. Требуется переподключение WhatsApp.`,
          );
        }

        // Ошибки с номером телефона - не повторяем
        if (
          errorLower.includes('invalid number') ||
          errorLower.includes('неверный номер') ||
          errorLower.includes('number not registered') ||
          errorLower.includes('номер не зарегистрирован')
        ) {
          throw new Error(
            `Неверный номер телефона: ${errorMessage}`,
          );
        }

        // Ошибки блокировки - не повторяем
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

        // Если это не последняя попытка, ждем перед повтором
        if (attempt < retries) {
          const delayMs = attempt * 3000; // 3, 6, 9 секунд задержка (увеличено)
          this.logger.log(
            `⏳ Ожидание ${delayMs}мс перед повторной попыткой...`,
          );
          await this.delay(delayMs);

          // Проверяем, что клиент все еще готов перед следующей попыткой
          if (!this.isReady || !this.client) {
            throw new Error(
              'WhatsApp клиент стал недоступен во время повторных попыток',
            );
          }

          // Проверяем состояние клиента
          try {
            const state = await this.client.getState();
            if (state !== 'CONNECTED') {
              this.logger.warn(`⚠️ Состояние клиента изменилось: ${state}`);
              this.isReady = false;
              throw new Error(`WhatsApp клиент отключен. Состояние: ${state}`);
            }
          } catch (stateError) {
            this.logger.warn(`⚠️ Не удалось проверить состояние: ${stateError.message}`);
          }
        }
      }
    }

    // Все попытки исчерпаны
    this.logger.error(
      `❌ Не удалось отправить сообщение на ${formattedPhone} после ${retries} попыток`,
    );
    this.logger.error(`   Последняя ошибка: ${lastError?.message}`);
    this.logger.error(`   Stack: ${lastError?.stack || 'N/A'}`);
    
    throw new Error(
      `Не удалось отправить сообщение после ${retries} попыток: ${lastError?.message}`,
    );
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
        // Получаем автомобиль клиента для замены {carModel} или {CarModel}
        let carModelText = 'автомобиль';
        if (recipient.customerId && options?.organizationId) {
          try {
            this.logger.log(
              `🔍 Поиск автомобилей для клиента ID: ${recipient.customerId}, организация: ${options.organizationId}`,
            );
            
            const vehicles = await this.vehiclesService.findByCustomer(
              options.organizationId,
              recipient.customerId,
            );
            
            this.logger.log(
              `📋 Найдено автомобилей для клиента ${recipient.customerId}: ${vehicles?.length || 0}`,
            );
            
            if (vehicles && vehicles.length > 0) {
              // Берем первый автомобиль клиента
              const vehicle = vehicles[0];
              // Формируем строку: "Toyota Camry 2020" или "Toyota Camry" если нет года
              carModelText = vehicle.year
                ? `${vehicle.brand} ${vehicle.model} ${vehicle.year}`
                : `${vehicle.brand} ${vehicle.model}`;
              
              this.logger.log(
                `🚗 Автомобиль клиента ${recipient.customerId}: ${carModelText}`,
              );
            } else {
              this.logger.warn(
                `⚠️ У клиента ${recipient.customerId} не найдено автомобилей. Будет использовано: "${carModelText}"`,
              );
            }
          } catch (e) {
            this.logger.error(
              `❌ Ошибка получения автомобиля для клиента ${recipient.customerId}: ${e.message}`,
            );
            this.logger.error(`   Stack: ${e.stack || 'N/A'}`);
          }
        } else {
          this.logger.warn(
            `⚠️ Не указан customerId (${recipient.customerId}) или organizationId (${options?.organizationId}). Будет использовано: "${carModelText}"`,
          );
        }

        // Подставляем переменные в шаблон (регистронезависимая замена)
        let personalizedMessage = template;
        
        this.logger.log(
          `🔄 Начало замены переменных для клиента ${recipient.name} (ID: ${recipient.customerId})`,
        );
        this.logger.log(`   Исходный шаблон: ${template}`);
        this.logger.log(`   carModelText: "${carModelText}"`);
        
        // Заменяем {name} или {Name}
        const nameValue = recipient.name || 'Уважаемый клиент';
        personalizedMessage = personalizedMessage.replace(
          /\{name\}/gi,
          nameValue,
        );
        this.logger.log(`   Заменено {name} на: "${nameValue}"`);
        
        // Заменяем {carModel} или {CarModel} (регистронезависимо)
        // Всегда выполняем замену, даже если переменной нет в шаблоне
        const beforeReplace = personalizedMessage;
        personalizedMessage = personalizedMessage.replace(
          /\{carModel\}/gi,
          carModelText,
        );
        
        if (beforeReplace !== personalizedMessage) {
          this.logger.log(`   ✅ Заменено {carModel} на: "${carModelText}"`);
        } else {
          this.logger.warn(`   ⚠️ Переменная {carModel} не найдена в шаблоне для замены!`);
          this.logger.warn(`   Шаблон содержит: ${template}`);
          // Попробуем найти все переменные в шаблоне
          const allVars = template.match(/\{[^}]+\}/g);
          if (allVars) {
            this.logger.warn(`   Найденные переменные в шаблоне: ${allVars.join(', ')}`);
          }
        }
        
        // Заменяем {organizationName} или {OrganizationName}
        if (options?.organizationId) {
          personalizedMessage = personalizedMessage.replace(
            /\{organizationName\}/gi,
            'наш сервис',
          );
        }
        
        this.logger.log(
          `📝 Финальное сообщение: ${personalizedMessage}`,
        );
        
        // Проверяем, остались ли не замененные переменные
        const remainingVars = personalizedMessage.match(/\{[^}]+\}/g);
        if (remainingVars && remainingVars.length > 0) {
          this.logger.warn(
            `⚠️ В сообщении остались не замененные переменные: ${remainingVars.join(', ')}`,
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
              this.logger.warn(
                `⚠️ Ошибка получения автомобиля для истории: ${e.message}`,
              );
            }
          }

          // Регистронезависимая замена для истории
          let historyMessage = template;
          historyMessage = historyMessage.replace(
            /\{name\}/gi,
            recipient.name || 'Уважаемый клиент',
          );
          historyMessage = historyMessage.replace(/\{carModel\}/gi, carModelText);
          historyMessage = historyMessage.replace(
            /\{organizationName\}/gi,
            'наш сервис',
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
    if (!phone || typeof phone !== 'string') {
      throw new Error('Номер телефона не указан или имеет неверный формат');
    }

    // Удаляем все символы кроме цифр
    let cleaned = phone.replace(/\D/g, '');

    if (!cleaned || cleaned.length === 0) {
      throw new Error('Номер телефона не содержит цифр');
    }

    // Если начинается с 8, заменяем на 7 (для России/Казахстана)
    if (cleaned.startsWith('8') && cleaned.length === 11) {
      cleaned = '7' + cleaned.substring(1);
    }

    // Убираем начальный + если есть (после очистки его уже не должно быть, но на всякий случай)
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    // Валидация длины номера (должно быть 10-15 цифр для международного формата)
    if (cleaned.length < 10 || cleaned.length > 15) {
      throw new Error(
        `Номер телефона имеет неверную длину: ${cleaned.length} цифр. Ожидается 10-15 цифр.`,
      );
    }

    // Для российских номеров проверяем, что начинается с 7
    if (cleaned.length === 11 && !cleaned.startsWith('7')) {
      this.logger.warn(
        `⚠️ Номер телефона ${cleaned} не начинается с 7, но имеет 11 цифр. Возможно, требуется форматирование.`,
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

