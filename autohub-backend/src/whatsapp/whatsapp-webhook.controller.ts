import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Res,
  HttpCode,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { getWhatsAppVerifyToken } from './whatsapp-verify.util';

/**
 * Meta WhatsApp Cloud API — верификация webhook (без JWT).
 * @see https://developers.facebook.com/docs/graph-api/webhooks/getting-started
 */
@Controller('api/whatsapp')
export class WhatsAppWebhookController {
  private readonly logger = new Logger(WhatsAppWebhookController.name);

  @Get('webhook')
  verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') verifyToken: string,
    @Query('hub.challenge') challenge: string,
    @Res() res: Response,
  ) {
    const expected = getWhatsAppVerifyToken();

    if (!expected) {
      this.logger.error(
        'WHATSAPP_WEBHOOK_VERIFY_TOKEN не задан в .env',
      );
      throw new ForbiddenException('Verify token not configured');
    }

    if (mode === 'subscribe' && verifyToken === expected && challenge) {
      this.logger.log('Meta webhook: проверка пройдена');
      return res.status(200).type('text/plain').send(challenge);
    }

    this.logger.warn('Meta webhook: неверный mode или verify_token');
    throw new ForbiddenException('Verification failed');
  }

  @Post('webhook')
  @HttpCode(200)
  receiveWebhook(@Body() body: Record<string, unknown>) {
    this.logger.log(
      `Meta webhook POST: ${JSON.stringify(body).slice(0, 800)}`,
    );
    return { success: true };
  }
}
