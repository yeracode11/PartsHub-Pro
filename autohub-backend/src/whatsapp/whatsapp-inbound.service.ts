import { Injectable, Logger } from '@nestjs/common';
import { MetaWebhookPayload } from './dto/meta-webhook.types';
import { parseMetaInboundEvents } from './meta-webhook.parser';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { MessageHistoryService } from './message-history.service';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

@Injectable()
export class WhatsAppInboundService {
  private readonly logger = new Logger(WhatsAppInboundService.name);

  constructor(
    private readonly tenantResolver: WhatsAppTenantResolver,
    private readonly messageHistoryService: MessageHistoryService,
    private readonly metaWhatsAppService: MetaWhatsAppService,
    private readonly metaConfig: MetaWhatsAppConfig,
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

    await this.sendEcho(
      tenant.connection,
      event.phoneNumberId,
      event.recipientWaId,
      text,
      event.messageId,
    );
  }

  private async sendEcho(
    connection: { accessToken: string },
    phoneNumberId: string,
    recipientWaId: string,
    inboundText: string,
    inboundMessageId: string,
  ): Promise<void> {
    const accessToken =
      connection.accessToken?.trim() || this.metaConfig.fallbackAccessToken;
    if (!accessToken) {
      this.logger.error(
        `META ECHO skipped: access token not configured inboundMessageId=${inboundMessageId}`,
      );
      return;
    }

    const echoBody = `Получил: ${inboundText}`;

    try {
      const result = await this.metaWhatsAppService.sendTextMessage(
        phoneNumberId,
        recipientWaId,
        echoBody,
        accessToken,
      );
      this.logger.log(
        `META ECHO SENT messageId=${inboundMessageId} outboundId=${result.messageId ?? 'n/a'}`,
      );
    } catch (error) {
      this.logger.error(
        `META ECHO failed inboundMessageId=${inboundMessageId}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
