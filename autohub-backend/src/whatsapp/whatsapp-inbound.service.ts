import { Injectable, Logger } from '@nestjs/common';
import { MetaWebhookPayload } from './dto/meta-webhook.types';
import { parseMetaInboundEvents } from './meta-webhook.parser';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { MessageHistoryService } from './message-history.service';

@Injectable()
export class WhatsAppInboundService {
  private readonly logger = new Logger(WhatsAppInboundService.name);

  constructor(
    private readonly tenantResolver: WhatsAppTenantResolver,
    private readonly messageHistoryService: MessageHistoryService,
  ) {}

  /**
   * Обработка Meta webhook. Всегда завершается без throw (controller → HTTP 200).
   */
  async handleWebhookPayload(body: MetaWebhookPayload): Promise<void> {
    const events = parseMetaInboundEvents(body);
    if (events.length === 0) {
      return;
    }

    for (const event of events) {
      await this.processInboundEvent(event);
    }
  }

  private async processInboundEvent(event: {
    phoneNumberId: string;
    wabaId?: string;
    messageId: string;
    from: string;
    type: string;
    textBody?: string;
  }): Promise<void> {
    const existing = await this.messageHistoryService.findByExternalMessageId(
      event.messageId,
    );
    if (existing) {
      this.logger.debug(
        `Duplicate Meta message skipped messageId=${event.messageId}`,
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

    if (event.type !== 'text') {
      await this.messageHistoryService.createInbound({
        organizationId: tenant.organizationId,
        whatsappConnectionId: tenant.connection.id,
        phone: event.from,
        externalMessageId: event.messageId,
        messageType: event.type,
        message: `[${event.type}]`,
        metadata: { wabaId: event.wabaId, unsupportedType: true },
      });
      return;
    }

    const text = event.textBody?.trim() ?? '';
    await this.messageHistoryService.createInbound({
      organizationId: tenant.organizationId,
      whatsappConnectionId: tenant.connection.id,
      phone: event.from,
      externalMessageId: event.messageId,
      messageType: 'text',
      message: text,
      metadata: { wabaId: event.wabaId },
    });
  }
}
