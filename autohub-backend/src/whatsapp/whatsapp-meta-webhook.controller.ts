import {
  Body,
  Controller,
  Get,
  HttpCode,
  Logger,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { WhatsAppInboundService } from './whatsapp-inbound.service';
import type { MetaWebhookPayload } from './dto/meta-webhook.types';

/**
 * Официальный WhatsApp Cloud API (Meta).
 * Callback URL: https://your-host/webhooks/whatsapp
 */
@Controller('webhooks/whatsapp')
export class WhatsAppMetaWebhookController {
  private readonly logger = new Logger(WhatsAppMetaWebhookController.name);

  constructor(
    private readonly metaConfig: MetaWhatsAppConfig,
    private readonly inboundService: WhatsAppInboundService,
  ) {}

  @Get()
  verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
    @Res() res: Response,
  ) {
    const verifyToken = this.metaConfig.verifyToken;

    this.logger.log(`Meta webhook verify mode=${mode}`);

    if (mode === 'subscribe' && verifyToken && token === verifyToken) {
      this.logger.log('Meta webhook verified successfully');
      return res.status(200).type('text/plain').send(challenge);
    }

    this.logger.warn('Meta webhook verification failed');
    return res.sendStatus(403);
  }

  @Post()
  @HttpCode(200)
  async receiveWebhook(@Body() body: MetaWebhookPayload) {
    try {
      await this.inboundService.handleWebhookPayload(body);
    } catch (error) {
      this.logger.error(
        `Meta webhook processing error: ${error instanceof Error ? error.message : String(error)}`,
      );
    }

    return { status: 'ok' };
  }
}
