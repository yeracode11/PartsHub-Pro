import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

export class MetaWhatsAppApiError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number,
    readonly metaCode?: number,
  ) {
    super(message);
    this.name = 'MetaWhatsAppApiError';
  }
}

@Injectable()
export class MetaWhatsAppService {
  private readonly logger = new Logger(MetaWhatsAppService.name);

  constructor(private readonly config: MetaWhatsAppConfig) {}

  /**
   * Отправка text через Meta Cloud API.
   * accessToken не логируется.
   */
  async sendTextMessage(
    phoneNumberId: string,
    recipientPhone: string,
    text: string,
    accessToken: string,
  ): Promise<{ messageId?: string }> {
    if (!accessToken?.trim()) {
      throw new MetaWhatsAppApiError('Access token is not configured');
    }

    const to = recipientPhone.replace(/\D/g, '');
    const url = this.config.messagesUrl(phoneNumberId);

    try {
      const response = await axios.post(
        url,
        {
          messaging_product: 'whatsapp',
          to,
          type: 'text',
          text: { body: text },
        },
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          timeout: 30_000,
        },
      );

      const messageId = response.data?.messages?.[0]?.id as string | undefined;
      return { messageId };
    } catch (error) {
      const axiosErr = error as AxiosError<{
        error?: { message?: string; code?: number };
      }>;
      const status = axiosErr.response?.status;
      const metaMessage =
        axiosErr.response?.data?.error?.message ||
        axiosErr.message ||
        'Meta API request failed';
      const metaCode = axiosErr.response?.data?.error?.code;

      this.logger.warn(
        `Meta send failed phoneNumberId=${phoneNumberId} status=${status ?? 'n/a'} code=${metaCode ?? 'n/a'}`,
      );

      throw new MetaWhatsAppApiError(metaMessage, status, metaCode);
    }
  }
}
