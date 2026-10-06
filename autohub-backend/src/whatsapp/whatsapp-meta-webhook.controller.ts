import {
  Body,
  Controller,
  Get,
  HttpCode,
  Logger,
  Post,
  Req,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request, Response } from 'express';
import { isValidMetaSignature } from './meta-webhook-signature.util';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { WhatsAppInboundService } from './whatsapp-inbound.service';
import type { MetaWebhookPayload } from './dto/meta-webhook.types';
import { parseMetaHubVerifyQuery } from './meta-webhook-verify.util';

/**
 * Официальный WhatsApp Cloud API (Meta).
 * Callback URL: https://your-host/webhooks/whatsapp
 */
@Controller('webhooks/whatsapp')
export class WhatsAppMetaWebhookController {
  private readonly logger = new Logger(WhatsAppMetaWebhookController.name);
  private unsignedWarningLogged = false;

  constructor(
    private readonly metaConfig: MetaWhatsAppConfig,
    private readonly inboundService: WhatsAppInboundService,
  ) {}

  @Get()
  verifyWebhook(@Req() req: Request, @Res() res: Response) {
    const { mode, verifyToken: token, challenge } = parseMetaHubVerifyQuery(
      req.query as Record<string, unknown>,
      req.originalUrl,
    );
    const { value: expectedToken, envKey } = this.metaConfig.resolveVerifyToken();

    if (!mode && !token && !challenge) {
      this.logger.debug(
        'Meta webhook GET without hub.* params (browser/health check, not Meta verify)',
      );
      return res.sendStatus(403);
    }

    this.logger.log(
      `Meta webhook verify mode=${mode ?? 'undefined'} envKey=${envKey ?? 'unset'} configured=${Boolean(expectedToken)} receivedLen=${token?.length ?? 0} configuredLen=${expectedToken.length}`,
    );

    if (
      mode === 'subscribe' &&
      expectedToken &&
      token === expectedToken &&
      challenge
    ) {
      this.logger.log('Meta webhook verified successfully');
      return res.status(200).type('text/plain').send(challenge);
    }

    this.logger.warn(
      'Meta webhook verification failed (token or mode mismatch)',
    );
    return res.sendStatus(403);
  }

  @Post()
  @HttpCode(200)
  async receiveWebhook(
    @Body() body: MetaWebhookPayload,
    @Req() req?: RawBodyRequest<Request>,
  ) {
    const appSecret = this.metaConfig.appSecret;
    if (appSecret) {
      const signature = req?.headers?.['x-hub-signature-256'];
      if (
        !isValidMetaSignature(
          req?.rawBody,
          typeof signature === 'string' ? signature : undefined,
          appSecret,
        )
      ) {
        this.logger.warn('Meta webhook rejected: invalid X-Hub-Signature-256');
        throw new UnauthorizedException();
      }
    } else if (!this.unsignedWarningLogged) {
      this.unsignedWarningLogged = true;
      this.logger.warn(
        'META_APP_SECRET is not set — Meta webhook signatures are not verified',
      );
    }

    this.logger.log(
      `META POST RECEIVED: ${JSON.stringify(body ?? {}).slice(0, 5000)}`,
    );

    try {
      await this.inboundService.handleWebhookPayload(body);
      this.logger.log('META POST PROCESSED SUCCESSFULLY');
    } catch (error) {
      this.logger.error(
        `Meta webhook processing error: ${
          error instanceof Error ? error.stack : String(error)
        }`,
      );
    }

    return { status: 'ok' };
  }
}
