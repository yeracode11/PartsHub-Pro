import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  MessageDirection,
  MessageHistory,
  MessageStatus,
} from '../entities/message-history.entity';
import { WhatsAppInboundService } from '../whatsapp-inbound.service';
import { WaGatewayClient, GatewayInstanceStatus } from './wa-gateway.client';
import { WaGatewayConfig } from './wa-gateway.config';
import {
  WhatsAppWebInstance,
  WhatsAppWebState,
} from './whatsapp-web-instance.entity';

/** Канал в message_history.metadata.channel для чатов через QR-шлюз. */
export const WEB_CHANNEL = 'web';

/** Кто написал исходящее: менеджер из CRM, сам магазин с телефона или бот. */
export type WebMessageSource = 'manager' | 'phone' | 'bot' | 'customer';

export type GatewayWebhookEvent =
  | {
      type: 'state';
      instanceId: string;
      state: WhatsAppWebState;
      phone?: string | null;
      reason?: string;
    }
  | {
      type: 'message';
      instanceId: string;
      messageId: string;
      phone: string;
      fromMe: boolean;
      pushName?: string | null;
      timestamp: number;
      messageType: string;
      text: string;
    };

export interface WebChatSummary {
  phone: string;
  name: string | null;
  lastMessage: string;
  lastDirection: MessageDirection;
  lastAt: Date;
  messagesCount: number;
}

export function normalizeChatPhone(input: string): string {
  let digits = (input ?? '').replace(/\D/g, '');
  if (digits.length === 11 && digits.startsWith('8'))
    digits = `7${digits.slice(1)}`;
  if (digits.length < 10 || digits.length > 15) {
    throw new BadRequestException('Некорректный номер телефона');
  }
  return digits;
}

/** Уникальный id сообщения в message_history: один и тот же WA id может быть у двух магазинов. */
export function webExternalId(
  organizationId: string,
  messageId: string,
): string {
  return `wa:${organizationId}:${messageId}`;
}

@Injectable()
export class WhatsAppWebService {
  private readonly logger = new Logger(WhatsAppWebService.name);

  constructor(
    @InjectRepository(WhatsAppWebInstance)
    private readonly instances: Repository<WhatsAppWebInstance>,
    @InjectRepository(MessageHistory)
    private readonly history: Repository<MessageHistory>,
    private readonly gateway: WaGatewayClient,
    private readonly config: WaGatewayConfig,
    private readonly inbound: WhatsAppInboundService,
  ) {}

  // ---------------------------------------------------------------- подключение

  async connect(organizationId: string) {
    const status = await this.gateway.start(organizationId);
    const row = await this.syncState(organizationId, status);
    return this.toView(row, status);
  }

  async status(organizationId: string) {
    await this.getOrCreate(organizationId);
    let status: GatewayInstanceStatus | null = null;
    try {
      status = await this.gateway.status(organizationId);
      await this.syncState(organizationId, status);
    } catch (error) {
      this.logger.warn(
        `gateway status unavailable organizationId=${organizationId}: ${(error as Error).message}`,
      );
    }
    return this.toView(await this.getOrCreate(organizationId), status, !status);
  }

  async logout(organizationId: string) {
    await this.gateway.logout(organizationId);
    await this.instances.update(
      { organizationId },
      { state: 'logged_out', phone: null, reason: null },
    );
    return this.status(organizationId);
  }

  async setBotEnabled(organizationId: string, enabled: boolean) {
    const row = await this.getOrCreate(organizationId);
    row.botEnabled = enabled;
    await this.instances.save(row);
    return this.status(organizationId);
  }

  // ---------------------------------------------------------------- чаты

  async listChats(
    organizationId: string,
    limit = 50,
    offset = 0,
  ): Promise<WebChatSummary[]> {
    const rows: Array<{
      phone: string;
      name: string | null;
      message: string;
      direction: MessageDirection;
      sentAt: Date;
      count: string;
    }> = await this.history.query(
      `
      SELECT DISTINCT ON (h."phone")
        h."phone",
        (SELECT x."metadata"->>'pushName' FROM "message_history" x
          WHERE x."organizationId" = h."organizationId" AND x."phone" = h."phone"
            AND x."metadata"->>'pushName' IS NOT NULL
          ORDER BY x."sentAt" DESC LIMIT 1) AS "name",
        h."message", h."direction", h."sentAt",
        COUNT(*) OVER (PARTITION BY h."phone") AS "count"
      FROM "message_history" h
      WHERE h."organizationId" = $1 AND h."metadata"->>'channel' = $2
      ORDER BY h."phone", h."sentAt" DESC
      `,
      [organizationId, WEB_CHANNEL],
    );
    return rows
      .map((r) => ({
        phone: r.phone,
        name: r.name,
        lastMessage: r.message,
        lastDirection: r.direction,
        lastAt: new Date(r.sentAt),
        messagesCount: Number(r.count),
      }))
      .sort((a, b) => b.lastAt.getTime() - a.lastAt.getTime())
      .slice(offset, offset + limit);
  }

  async chatMessages(
    organizationId: string,
    rawPhone: string,
    limit = 50,
    before?: Date,
  ) {
    const phone = normalizeChatPhone(rawPhone);
    const qb = this.history
      .createQueryBuilder('h')
      .where('h.organizationId = :organizationId', { organizationId })
      .andWhere('h.phone = :phone', { phone })
      .andWhere(`h.metadata->>'channel' = :channel`, { channel: WEB_CHANNEL })
      .orderBy('h.sentAt', 'DESC')
      .take(Math.min(Math.max(limit, 1), 200));
    if (before && !Number.isNaN(before.getTime())) {
      qb.andWhere('h.sentAt < :before', { before });
    }
    const items = await qb.getMany();
    return items.reverse().map((m) => ({
      id: m.id,
      direction: m.direction,
      text: m.message,
      messageType: m.messageType,
      status: m.status,
      source: (m.metadata?.source as WebMessageSource | undefined) ?? null,
      sentBy: m.sentBy,
      sentAt: m.sentAt,
      errorMessage: m.errorMessage,
    }));
  }

  async sendFromManager(
    organizationId: string,
    userId: string | null,
    rawPhone: string,
    text: string,
  ) {
    const phone = normalizeChatPhone(rawPhone);
    const body = (text ?? '').trim();
    if (!body || body.length > 4096) {
      throw new BadRequestException(
        'Текст сообщения пустой или длиннее 4096 символов',
      );
    }
    const result = await this.gateway.sendText(organizationId, phone, body);
    return this.saveOutbound(
      organizationId,
      phone,
      body,
      result.messageId,
      'manager',
      userId,
    );
  }

  async sendFileFromManager(
    organizationId: string,
    userId: string | null,
    rawPhone: string,
    file: {
      url: string;
      fileName?: string;
      mimetype?: string;
      caption?: string;
    },
  ) {
    const phone = normalizeChatPhone(rawPhone);
    if (!/^https?:\/\//.test(file.url ?? '')) {
      throw new BadRequestException('Нужна ссылка на файл (http/https)');
    }
    const result = await this.gateway.sendFile(organizationId, phone, file);
    const label = file.caption?.trim() || `[файл] ${file.fileName ?? file.url}`;
    return this.saveOutbound(
      organizationId,
      phone,
      label,
      result.messageId,
      'manager',
      userId,
      {
        fileUrl: file.url,
        mimetype: file.mimetype,
      },
    );
  }

  // ---------------------------------------------------------------- вебхук шлюза

  async handleGatewayEvent(event: GatewayWebhookEvent): Promise<void> {
    const organizationId = event.instanceId;
    const row = await this.instances.findOne({ where: { organizationId } });
    if (!row) {
      this.logger.warn(
        `gateway event for unknown organizationId=${organizationId}`,
      );
      return;
    }

    if (event.type === 'state') {
      row.state = event.state;
      if (event.phone !== undefined) row.phone = event.phone ?? row.phone;
      row.reason = event.reason ?? null;
      if (event.state === 'logged_out') row.phone = null;
      await this.instances.save(row);
      return;
    }

    const phone = event.phone;
    const source: WebMessageSource = event.fromMe ? 'phone' : 'customer';
    const saved = await this.saveIfNew({
      organizationId,
      phone,
      externalMessageId: webExternalId(organizationId, event.messageId),
      direction: event.fromMe
        ? MessageDirection.OUTBOUND
        : MessageDirection.INBOUND,
      messageType: event.messageType,
      message: event.text || `[${event.messageType}]`,
      metadata: {
        channel: WEB_CHANNEL,
        source,
        pushName: event.fromMe ? null : (event.pushName ?? null),
        waTimestamp: event.timestamp,
      },
    });
    if (!saved) return; // дубль: например, наше же исходящее вернулось эхом

    if (event.fromMe || !row.botEnabled) return;
    if (event.messageType !== 'text' || !event.text.trim()) return;

    // Ответ бота не держит вебхук: шлюз ждёт ответ не дольше 15 секунд.
    void this.replyWithBot(organizationId, phone, event.text).catch((error) =>
      this.logger.error(
        `[WEB BOT] reply failed organizationId=${organizationId}: ${(error as Error).message}`,
      ),
    );
  }

  /** Бот молчит, если менеджер недавно сам писал в этот чат. */
  async isManagerActive(
    organizationId: string,
    phone: string,
  ): Promise<boolean> {
    const minutes = this.config.botPauseAfterManagerMinutes;
    if (minutes === 0) return false;
    const since = new Date(Date.now() - minutes * 60_000);
    const count = await this.history
      .createQueryBuilder('h')
      .where('h.organizationId = :organizationId', { organizationId })
      .andWhere('h.phone = :phone', { phone })
      .andWhere('h.direction = :dir', { dir: MessageDirection.OUTBOUND })
      .andWhere(`h.metadata->>'channel' = :channel`, { channel: WEB_CHANNEL })
      .andWhere(`h.metadata->>'source' IN ('manager', 'phone')`)
      .andWhere('h.sentAt > :since', { since })
      .getCount();
    return count > 0;
  }

  private async replyWithBot(
    organizationId: string,
    phone: string,
    text: string,
  ) {
    if (await this.isManagerActive(organizationId, phone)) {
      this.logger.log(
        `[WEB BOT] skipped: manager active organizationId=${organizationId}`,
      );
      return;
    }
    const reply = await this.inbound.generateBotReply(organizationId, text);
    if (!reply) return;
    const result = await this.gateway.sendText(organizationId, phone, reply);
    await this.saveOutbound(
      organizationId,
      phone,
      reply,
      result.messageId,
      'bot',
      null,
    );
  }

  // ---------------------------------------------------------------- служебное

  private async saveOutbound(
    organizationId: string,
    phone: string,
    text: string,
    messageId: string | null,
    source: WebMessageSource,
    userId: string | null,
    extra: Record<string, unknown> = {},
  ) {
    const record = await this.saveIfNew({
      organizationId,
      phone,
      externalMessageId: messageId
        ? webExternalId(organizationId, messageId)
        : null,
      direction: MessageDirection.OUTBOUND,
      messageType: extra.fileUrl ? 'document' : 'text',
      message: text,
      sentBy: userId,
      metadata: { channel: WEB_CHANNEL, source, ...extra },
    });
    if (record) return record;
    // Эхо от шлюза успело раньше нас: дополняем запись автором.
    const existing = await this.history.findOne({
      where: {
        externalMessageId: webExternalId(organizationId, messageId ?? ''),
      },
    });
    if (existing) {
      existing.sentBy = userId;
      existing.metadata = { ...(existing.metadata ?? {}), source, ...extra };
      return this.history.save(existing);
    }
    return null;
  }

  private async saveIfNew(data: {
    organizationId: string;
    phone: string;
    externalMessageId: string | null;
    direction: MessageDirection;
    messageType: string;
    message: string;
    sentBy?: string | null;
    metadata: Record<string, unknown>;
  }): Promise<MessageHistory | null> {
    if (data.externalMessageId) {
      const existing = await this.history.findOne({
        where: { externalMessageId: data.externalMessageId },
      });
      if (existing) return null;
    }
    try {
      return await this.history.save(
        this.history.create({
          organizationId: data.organizationId,
          whatsappConnectionId: null,
          phone: data.phone,
          externalMessageId: data.externalMessageId,
          direction: data.direction,
          messageType: data.messageType,
          message: data.message,
          metadata: data.metadata,
          status: MessageStatus.SENT,
          sentBy: data.sentBy ?? null,
          isBulk: false,
        }),
      );
    } catch (error) {
      if ((error as { code?: string })?.code === '23505') return null;
      throw error;
    }
  }

  private async getOrCreate(
    organizationId: string,
  ): Promise<WhatsAppWebInstance> {
    const existing = await this.instances.findOne({
      where: { organizationId },
    });
    if (existing) return existing;
    return this.instances.save(
      this.instances.create({
        organizationId,
        state: 'stopped',
        botEnabled: false,
      }),
    );
  }

  private async syncState(
    organizationId: string,
    status: GatewayInstanceStatus,
  ) {
    const row = await this.getOrCreate(organizationId);
    row.state = status.state;
    if (status.phone) row.phone = status.phone;
    row.reason = status.reason ?? null;
    return this.instances.save(row);
  }

  private toView(
    row: WhatsAppWebInstance,
    status: GatewayInstanceStatus | null,
    gatewayUnavailable = false,
  ) {
    return {
      state: row.state,
      phone: row.phone,
      reason: row.reason,
      botEnabled: row.botEnabled,
      qrDataUrl: status?.qrDataUrl ?? null,
      sentToday: status?.sentToday ?? null,
      remainingToday: status?.remainingToday ?? null,
      gatewayUnavailable,
    };
  }
}
