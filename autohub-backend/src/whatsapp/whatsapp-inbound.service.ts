import { Injectable, Logger } from '@nestjs/common';
import { MetaWebhookPayload } from './dto/meta-webhook.types';
import { parseMetaInboundEvents } from './meta-webhook.parser';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { MessageHistoryService } from './message-history.service';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { QwenService } from '../ai/qwen.service';
import { QwenIntentResult } from '../ai/qwen-intent.types';
import { StockService } from '../inventory/stock.service';

@Injectable()
export class WhatsAppInboundService {
  private readonly logger = new Logger(WhatsAppInboundService.name);

  constructor(
    private readonly tenantResolver: WhatsAppTenantResolver,
    private readonly messageHistoryService: MessageHistoryService,
    private readonly metaWhatsAppService: MetaWhatsAppService,
    private readonly metaConfig: MetaWhatsAppConfig,
    private readonly qwenService: QwenService,
    private readonly stockService: StockService,
  ) {}

  /**
   * Обработка Meta webhook. Всегда завершается без throw (controller → HTTP 200).
   */
  async handleWebhookPayload(body: MetaWebhookPayload): Promise<void> {
    this.logger.log('META INBOUND SERVICE CALLED');

    const events = parseMetaInboundEvents(body);
    if (events.length === 0) {
      this.logger.log(
        `META INBOUND: no message events parsed object=${body?.object ?? 'n/a'} entries=${body?.entry?.length ?? 0}`,
      );
      return;
    }

    for (const event of events) {
      this.logger.log(
        `META INBOUND phone_number_id=${event.phoneNumberId} messageId=${event.messageId}`,
      );
      try {
        await this.processInboundEvent(event);
      } catch (error) {
        this.logger.error(
          `META INBOUND event failed messageId=${event.messageId}: ${
            error instanceof Error ? error.stack : String(error)
          }`,
        );
      }
    }
  }

  private async processInboundEvent(event: {
    phoneNumberId: string;
    wabaId?: string;
    messageId: string;
    from: string;
    recipientWaId: string;
    type: string;
    textBody?: string;
  }): Promise<void> {
    const existing = await this.messageHistoryService.findByExternalMessageId(
      event.messageId,
    );
    if (existing) {
      this.logger.log(
        `META MESSAGE duplicate skipped messageId=${event.messageId}`,
      );
      return;
    }

    const tenant = await this.tenantResolver.resolveByPhoneNumberId(
      event.phoneNumberId,
    );
    if (!tenant) {
      this.logger.warn(
        `Unknown Meta phone_number_id=${event.phoneNumberId} messageId=${event.messageId}`,
      );
      return;
    }

    this.logger.log(
      `META TENANT RESOLVED organizationId=${tenant.organizationId} phone_number_id=${event.phoneNumberId}`,
    );

    const baseInbound = {
      organizationId: tenant.organizationId,
      whatsappConnectionId: tenant.connection.id,
      phone: event.from,
      externalMessageId: event.messageId,
      metadata: { wabaId: event.wabaId },
    };

    if (event.type !== 'text') {
      const saved = await this.messageHistoryService.createInbound({
        ...baseInbound,
        messageType: event.type,
        message: `[${event.type}]`,
        metadata: { ...baseInbound.metadata, unsupportedType: true },
      });
      if (saved?.created) {
        this.logger.log(
          `META MESSAGE SAVED messageId=${event.messageId} type=${event.type}`,
        );
      }
      return;
    }

    const text = event.textBody?.trim() ?? '';
    const saved = await this.messageHistoryService.createInbound({
      ...baseInbound,
      messageType: 'text',
      message: text,
    });

    if (!saved) {
      return;
    }

    if (!saved.created) {
      this.logger.log(
        `META MESSAGE duplicate skipped messageId=${event.messageId}`,
      );
      return;
    }

    this.logger.log(`META MESSAGE SAVED messageId=${event.messageId}`);

    const intent = await this.resolveQwenIntent(text, tenant.organizationId);
    const replyText = await this.buildOutboundReply(
      tenant.organizationId,
      text,
      intent,
    );

    await this.sendWhatsAppText(
      tenant.connection,
      event.phoneNumberId,
      event.recipientWaId,
      replyText,
      event.messageId,
      intent?.intent === 'check_stock' ? 'stock' : 'echo',
    );
  }

  private async resolveQwenIntent(
    messageText: string,
    organizationId: string,
  ): Promise<QwenIntentResult | null> {
    try {
      const intent = await this.qwenService.parseIntent(messageText);
      if (!intent) {
        this.logger.warn('[AI] intent unavailable or invalid');
        return null;
      }
      this.logSafeQwenIntent(organizationId, intent);
      return intent;
    } catch (error) {
      this.logger.error(
        `[AI] intent failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return null;
    }
  }

  private logSafeQwenIntent(
    organizationId: string,
    result: QwenIntentResult,
  ): void {
    const vehicle = [
      result.vehicle.brand,
      result.vehicle.model,
      result.vehicle.generation,
    ]
      .filter(Boolean)
      .join(' ');
    const part = result.part.name ?? 'n/a';
    const position = result.part.position ?? 'n/a';

    this.logger.log(
      `[AI] intent=${result.intent} organizationId=${organizationId} vehicle=${vehicle || 'n/a'} part=${part} position=${position}`,
    );
  }

  private async buildOutboundReply(
    organizationId: string,
    inboundText: string,
    intent: QwenIntentResult | null,
  ): Promise<string> {
    if (intent?.intent === 'check_stock') {
      try {
        const stockReply = await this.stockService.buildCheckStockReply(
          organizationId,
          intent,
        );
        this.logger.log('[WHATSAPP] stock response prepared');
        return stockReply;
      } catch (error) {
        this.logger.error(
          `[STOCK] check_stock failed: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      }
    }

    return `Получил: ${inboundText}`;
  }

  private async sendWhatsAppText(
    connection: { accessToken: string },
    phoneNumberId: string,
    recipientWaId: string,
    body: string,
    inboundMessageId: string,
    kind: 'echo' | 'stock',
  ): Promise<void> {
    const envToken = this.metaConfig.fallbackAccessToken?.trim();
    const connectionToken = connection.accessToken?.trim();
    const accessToken = envToken || connectionToken;
    const tokenSource = envToken ? 'env' : connectionToken ? 'connection' : 'none';

    if (!accessToken) {
      this.logger.error(
        `META outbound skipped: access token not configured inboundMessageId=${inboundMessageId}`,
      );
      return;
    }

    this.logger.log(`META outbound token source=${tokenSource} kind=${kind}`);

    try {
      const result = await this.metaWhatsAppService.sendTextMessage(
        phoneNumberId,
        recipientWaId,
        body,
        accessToken,
      );
      if (kind === 'stock') {
        this.logger.log(
          `[WHATSAPP] stock response sent messageId=${inboundMessageId} outboundId=${result.messageId ?? 'n/a'}`,
        );
      } else {
        this.logger.log(
          `META ECHO SENT messageId=${inboundMessageId} outboundId=${result.messageId ?? 'n/a'}`,
        );
      }
    } catch (error) {
      this.logger.error(
        `META outbound failed kind=${kind} inboundMessageId=${inboundMessageId}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
