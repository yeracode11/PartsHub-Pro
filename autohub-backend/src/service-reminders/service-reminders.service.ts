import {
  BadRequestException,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import {
  WhatsAppConnection,
  WhatsAppConnectionStatus,
} from '../whatsapp/entities/whatsapp-connection.entity';
import { MetaWhatsAppService } from '../whatsapp/meta-whatsapp.service';
import { businessToday } from '../donors/donor-status';
import { ServiceReminderSettings } from './entities/service-reminder-settings.entity';
import { ServiceReminderLog } from './entities/service-reminder-log.entity';

export const REMINDER_TEMPLATE = {
  name: 'service_reminder',
  language: 'ru',
  body:
    'Здравствуйте, {{1}}! Напоминаем: автомобилю {{2}} пора пройти техническое обслуживание — {{3}}. Ответьте на это сообщение, чтобы записаться.',
  example: ['Иван', 'Toyota Camry 110ERS11', '20.10.2026'],
};

/** Не чаще одной попытки за это время и не больше MAX_ATTEMPTS на одну дату ТО. */
const RETRY_AFTER_HOURS = 20;
const MAX_ATTEMPTS = 3;
/** Пропущенные дни (сервер лежал) догоняем не дальше недели назад. */
const OVERDUE_DAYS = 7;
/** Пишем клиентам только днём по времени бизнеса. */
const SEND_FROM_HOUR = 10;
const SEND_TO_HOUR = 19;
const TICK_MS = 60 * 60 * 1000;

export interface DueReminder {
  vehicleId: number;
  customerId: number;
  customerName: string;
  phone: string;
  car: string;
  dueDate: string;
}

function addDays(isoDate: string, days: number): string {
  const date = new Date(`${isoDate}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().substring(0, 10);
}

function ruDate(isoDate: string): string {
  const [y, m, d] = isoDate.split('-');
  return `${d}.${m}.${y}`;
}

function businessHour(now: Date): number {
  const timeZone = process.env.APP_TIME_ZONE?.trim() || 'Asia/Almaty';
  return Number(
    new Intl.DateTimeFormat('en-US', { timeZone, hour: 'numeric', hourCycle: 'h23' }).format(now),
  );
}

@Injectable()
export class ServiceRemindersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ServiceRemindersService.name);
  private timer?: NodeJS.Timeout;

  constructor(
    @InjectRepository(ServiceReminderSettings)
    private readonly settingsRepository: Repository<ServiceReminderSettings>,
    @InjectRepository(ServiceReminderLog)
    private readonly logRepository: Repository<ServiceReminderLog>,
    @InjectRepository(Vehicle)
    private readonly vehicleRepository: Repository<Vehicle>,
    @InjectRepository(WhatsAppConnection)
    private readonly connectionRepository: Repository<WhatsAppConnection>,
    private readonly meta: MetaWhatsAppService,
  ) {}

  onModuleInit() {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => {
      void this.tick().catch((error) =>
        this.logger.warn(`service reminders tick failed: ${error?.message}`),
      );
    }, TICK_MS);
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  /** Раз в час: по каждой организации с включёнными напоминаниями, только днём. */
  async tick(now = new Date()) {
    const hour = businessHour(now);
    if (hour < SEND_FROM_HOUR || hour >= SEND_TO_HOUR) return;
    const enabled = await this.settingsRepository.find({ where: { enabled: true } });
    for (const settings of enabled) {
      try {
        await this.runForOrganization(settings.organizationId, now);
      } catch (error) {
        this.logger.warn(
          `service reminders org=${settings.organizationId} failed: ${(error as Error).message}`,
        );
      }
    }
  }

  async getSettings(organizationId: string): Promise<ServiceReminderSettings> {
    return (
      (await this.settingsRepository.findOne({ where: { organizationId } })) ??
      this.settingsRepository.create({
        organizationId,
        enabled: false,
        daysBefore: 3,
        connectionId: null,
        templateStatus: null,
        templateError: null,
      })
    );
  }

  /** Экран настроек: настройки, кому напомним в ближайшие дни, последние отправки. */
  async getOverview(organizationId: string, now = new Date()) {
    const settings = await this.getSettings(organizationId);
    const connections = await this.connectionRepository.find({
      where: { organizationId, status: WhatsAppConnectionStatus.ACTIVE },
      order: { createdAt: 'DESC' },
    });
    const upcoming = await this.findDue(organizationId, settings.daysBefore, now, false);
    const recent = await this.logRepository
      .createQueryBuilder('log')
      .leftJoin(Vehicle, 'v', 'v.id = log."vehicleId"')
      .leftJoin('v.customer', 'c')
      .select('log.id', 'id')
      .addSelect('log.status', 'status')
      .addSelect('log.error', 'error')
      .addSelect('log.attempts', 'attempts')
      .addSelect(`to_char(log."dueDate", 'YYYY-MM-DD')`, 'dueDate')
      .addSelect('log."lastAttemptAt"', 'lastAttemptAt')
      .addSelect('c.name', 'customerName')
      .addSelect(`TRIM(CONCAT_WS(' ', v.brand, v.model, v."plateNumber"))`, 'car')
      .where('log.organizationId = :organizationId', { organizationId })
      .orderBy('log."lastAttemptAt"', 'DESC')
      .limit(20)
      .getRawMany();
    return {
      settings,
      template: { name: REMINDER_TEMPLATE.name, body: REMINDER_TEMPLATE.body },
      connections: connections.map((c) => ({
        id: c.id,
        phoneNumber: c.phoneNumber,
        displayName: c.displayName,
        hasWaba: Boolean(c.wabaId),
      })),
      upcoming,
      recent,
    };
  }

  async updateSettings(
    organizationId: string,
    input: { enabled?: boolean; daysBefore?: number; connectionId?: string | null },
  ) {
    const settings = await this.getSettings(organizationId);
    if (input.daysBefore !== undefined) {
      const days = Number(input.daysBefore);
      if (!Number.isInteger(days) || days < 0 || days > 30) {
        throw new BadRequestException('За сколько дней напоминать: от 0 до 30');
      }
      settings.daysBefore = days;
    }
    if (input.connectionId !== undefined) {
      settings.connectionId = input.connectionId || null;
    }
    if (input.enabled !== undefined) settings.enabled = Boolean(input.enabled);

    if (settings.enabled) {
      const connection = await this.resolveConnection(organizationId, settings.connectionId);
      settings.connectionId = connection.id;
      await this.ensureTemplate(settings, connection);
    }
    return this.settingsRepository.save(settings);
  }

  /**
   * Кому пора напомнить: дата следующего ТО в окне [сегодня − неделя, сегодня + daysBefore],
   * у клиента есть телефон, напоминание ещё не отправлено и попытки не исчерпаны.
   */
  async findDue(
    organizationId: string,
    daysBefore: number,
    now = new Date(),
    respectRetry = true,
  ): Promise<DueReminder[]> {
    const today = businessToday(now);
    const query = this.vehicleRepository
      .createQueryBuilder('v')
      .innerJoin('v.customer', 'c')
      .leftJoin(
        ServiceReminderLog,
        'log',
        `log."organizationId" = v."organizationId" AND log."vehicleId" = v.id
         AND log."dueDate" = v."nextServiceDate"`,
      )
      .select('v.id', 'vehicleId')
      .addSelect('c.id', 'customerId')
      .addSelect('c.name', 'customerName')
      .addSelect('c.phone', 'phone')
      .addSelect(`TRIM(CONCAT_WS(' ', v.brand, v.model, v."plateNumber"))`, 'car')
      .addSelect(`to_char(v."nextServiceDate", 'YYYY-MM-DD')`, 'dueDate')
      .where('v.organizationId = :organizationId', { organizationId })
      .andWhere('v.isActive = true')
      .andWhere('v."nextServiceDate" BETWEEN :from AND :to', {
        from: addDays(today, -OVERDUE_DAYS),
        to: addDays(today, daysBefore),
      })
      .andWhere(`COALESCE(TRIM(c.phone), '') <> ''`)
      .andWhere(`(log.id IS NULL OR log.status <> 'sent')`)
      .orderBy('v."nextServiceDate"', 'ASC');
    if (respectRetry) {
      query.andWhere(
        `(log.id IS NULL OR (log.attempts < :maxAttempts AND log."lastAttemptAt" < :retryBefore))`,
        {
          maxAttempts: MAX_ATTEMPTS,
          retryBefore: new Date(now.getTime() - RETRY_AFTER_HOURS * 60 * 60 * 1000),
        },
      );
    }
    const rows = await query.getRawMany<DueReminder>();
    return rows.map((row) => ({
      ...row,
      vehicleId: Number(row.vehicleId),
      customerId: Number(row.customerId),
    }));
  }

  /** Отправить всё, что пора. Возвращает счётчики; шаблон не одобрен — ничего не шлёт. */
  async runForOrganization(organizationId: string, now = new Date()) {
    const settings = await this.getSettings(organizationId);
    if (!settings.enabled) return { sent: 0, failed: 0, skipped: 'disabled' as const };

    const connection = await this.resolveConnection(organizationId, settings.connectionId);
    if (settings.templateStatus !== 'APPROVED') {
      await this.ensureTemplate(settings, connection);
      await this.settingsRepository.save(settings);
      if (settings.templateStatus !== 'APPROVED') {
        return { sent: 0, failed: 0, skipped: 'template' as const };
      }
    }

    let sent = 0;
    let failed = 0;
    for (const due of await this.findDue(organizationId, settings.daysBefore, now)) {
      try {
        const { messageId } = await this.meta.sendTemplateMessage(
          connection.phoneNumberId,
          due.phone,
          {
            name: REMINDER_TEMPLATE.name,
            language: REMINDER_TEMPLATE.language,
            bodyParams: [due.customerName || 'клиент', due.car, ruDate(due.dueDate)],
          },
          connection.accessToken,
        );
        await this.writeLog(organizationId, due, 'sent', messageId ?? null, null, now);
        sent++;
      } catch (error) {
        await this.writeLog(organizationId, due, 'failed', null, (error as Error).message, now);
        failed++;
      }
    }
    return { sent, failed, skipped: null };
  }

  private async writeLog(
    organizationId: string,
    due: DueReminder,
    status: 'sent' | 'failed',
    messageId: string | null,
    error: string | null,
    now: Date,
  ) {
    const existing = await this.logRepository.findOne({
      where: { organizationId, vehicleId: due.vehicleId, dueDate: due.dueDate },
    });
    if (existing) {
      existing.status = status;
      existing.messageId = messageId;
      existing.error = error;
      existing.attempts += 1;
      existing.lastAttemptAt = now;
      await this.logRepository.save(existing);
      return;
    }
    await this.logRepository.save(
      this.logRepository.create({
        organizationId,
        vehicleId: due.vehicleId,
        customerId: due.customerId,
        dueDate: due.dueDate,
        status,
        messageId,
        error,
        attempts: 1,
        lastAttemptAt: now,
      }),
    );
  }

  private async resolveConnection(organizationId: string, connectionId: string | null) {
    const connection = await this.connectionRepository.findOne({
      where: {
        organizationId,
        status: WhatsAppConnectionStatus.ACTIVE,
        ...(connectionId ? { id: connectionId } : {}),
      },
      order: { createdAt: 'DESC' },
    });
    if (!connection) {
      throw new BadRequestException(
        'Нет активного подключения WhatsApp. Подключите номер в разделе WhatsApp.',
      );
    }
    return connection;
  }

  /** Проверяет шаблон в Meta и создаёт его, если его нет. Пишет статус в настройки. */
  private async ensureTemplate(settings: ServiceReminderSettings, connection: WhatsAppConnection) {
    if (!connection.wabaId) {
      settings.templateStatus = 'MISSING';
      settings.templateError =
        'У подключения не указан WhatsApp Business Account ID — шаблон создать нельзя.';
      return;
    }
    try {
      let current = await this.meta.getTemplateStatus(
        connection.wabaId,
        REMINDER_TEMPLATE.name,
        connection.accessToken,
      );
      if (!current) {
        const created = await this.meta.createUtilityTemplate(
          connection.wabaId,
          REMINDER_TEMPLATE,
          connection.accessToken,
        );
        current = { status: created.status ?? 'PENDING' };
      }
      settings.templateStatus = current.status;
      settings.templateError = current.rejectedReason ?? null;
    } catch (error) {
      settings.templateStatus = settings.templateStatus ?? 'MISSING';
      settings.templateError = (error as Error).message;
    }
  }
}
