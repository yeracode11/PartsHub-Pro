import {
  Body,
  Controller,
  HttpCode,
  Logger,
  Post,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';
import { isValidMetaSignature } from '../meta-webhook-signature.util';
import { WaGatewayConfig } from './wa-gateway.config';
import { WhatsAppWebService } from './whatsapp-web.service';
import type { GatewayWebhookEvent } from './whatsapp-web.service';

/** События от whatsapp-gateway: входящие сообщения и смена состояния номера. */
@Controller('webhooks/wa-gateway')
export class WaGatewayWebhookController {
  private readonly logger = new Logger(WaGatewayWebhookController.name);

  constructor(
    private readonly config: WaGatewayConfig,
    private readonly web: WhatsAppWebService,
  ) {}

  @Post()
  @HttpCode(200)
  async receive(
    @Body() body: GatewayWebhookEvent,
    @Req() req: RawBodyRequest<Request>,
  ) {
    const secret = this.config.webhookSecret;
    const signature = req.headers['x-vinly-signature'];
    // Подпись тем же форматом, что у Meta: sha256=<hex HMAC тела>.
    if (
      !secret ||
      !isValidMetaSignature(
        req.rawBody,
        typeof signature === 'string' ? signature : undefined,
        secret,
      )
    ) {
      this.logger.warn('wa-gateway webhook rejected: bad or missing signature');
      throw new UnauthorizedException();
    }
    await this.web.handleGatewayEvent(body);
    return { ok: true };
  }
}
