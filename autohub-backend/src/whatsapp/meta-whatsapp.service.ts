import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { WhatsAppMetaRecipientCacheService } from './whatsapp-meta-recipient-cache.service';
import { toMetaWhatsAppDigits } from './meta-whatsapp-recipient.util';

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

  constructor(
    private readonly config: MetaWhatsAppConfig,
    private readonly recipientCache: WhatsAppMetaRecipientCacheService,
  ) {}

  /**
   * Отправка text через Meta Cloud API.
   * accessToken не логируется.
   */
  /**
   * @param recipientWaId WhatsApp ID из webhook (messages[].from / contacts[].wa_id).
   */
  async sendTextMessage(
    phoneNumberId: string,
    recipientWaId: string,
    text: string,
    accessToken: string,
  ): Promise<{ messageId?: string }> {
    if (!accessToken?.trim()) {
      throw new MetaWhatsAppApiError('Access token is not configured');
    }

    const waId = toMetaWhatsAppDigits(recipientWaId);
    const cachedInput = await this.recipientCache.resolveGraphApiTo(waId);
    const to = cachedInput ?? waId;
    const usedCache = cachedInput != null && cachedInput !== waId;

    this.logger.log(
      `META OUTBOUND resolve waId=${waId} usedGraphInputCache=${usedCache}`,
    );

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

      const contact = response.data?.contacts?.[0] as
        | { input?: string; wa_id?: string }
        | undefined;
      await this.recipientCache.rememberFromMetaResponse(
        contact?.wa_id ?? waId,
        contact?.input,
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
        `Meta send failed phoneNumberId=${phoneNumberId} status=${status ?? 'n/a'} code=${metaCode ?? 'n/a'} waId=${waId} toLen=${to.length}`,
      );

      if (metaCode === 131030) {
        this.logger.warn(
          `Meta 131030: verify app test recipients include waId=${waId}, or seed whatsapp_meta_recipient_cache from a successful Graph API contacts.input for this wa_id`,
        );
      }

      throw new MetaWhatsAppApiError(metaMessage, status, metaCode);
    }
  }

  /**
   * Сообщение по одобренному шаблону. Только так можно написать клиенту первым
   * (вне 24-часового окна после его последнего сообщения).
   */
  async sendTemplateMessage(
    phoneNumberId: string,
    recipient: string,
    template: { name: string; language: string; bodyParams: string[] },
    accessToken: string,
  ): Promise<{ messageId?: string }> {
    if (!accessToken?.trim()) {
      throw new MetaWhatsAppApiError('Access token is not configured');
    }
    const to = toMetaWhatsAppDigits(recipient);
    try {
      const response = await axios.post(
        this.config.messagesUrl(phoneNumberId),
        {
          messaging_product: 'whatsapp',
          to,
          type: 'template',
          template: {
            name: template.name,
            language: { code: template.language },
            components: [
              {
                type: 'body',
                parameters: template.bodyParams.map((text) => ({ type: 'text', text })),
              },
            ],
          },
        },
        { headers: this.authHeaders(accessToken), timeout: 30_000 },
      );
      return { messageId: response.data?.messages?.[0]?.id as string | undefined };
    } catch (error) {
      throw this.toApiError(error, `template send phoneNumberId=${phoneNumberId}`);
    }
  }

  /** Статус шаблона в аккаунте WhatsApp Business: APPROVED, PENDING, REJECTED… или null, если его нет. */
  async getTemplateStatus(
    wabaId: string,
    name: string,
    accessToken: string,
  ): Promise<{ status: string; rejectedReason?: string } | null> {
    try {
      const response = await axios.get(this.config.messageTemplatesUrl(wabaId), {
        params: { name, fields: 'name,status,rejected_reason,language' },
        headers: this.authHeaders(accessToken),
        timeout: 30_000,
      });
      const row = (response.data?.data as Array<Record<string, string>> | undefined)?.find(
        (t) => t.name === name,
      );
      return row ? { status: row.status, rejectedReason: row.rejected_reason } : null;
    } catch (error) {
      throw this.toApiError(error, `template status wabaId=${wabaId}`);
    }
  }

  /** Создаёт шаблон категории UTILITY. Meta проверяет его от минут до суток. */
  async createUtilityTemplate(
    wabaId: string,
    template: { name: string; language: string; body: string; example: string[] },
    accessToken: string,
  ): Promise<{ status?: string }> {
    try {
      const response = await axios.post(
        this.config.messageTemplatesUrl(wabaId),
        {
          name: template.name,
          language: template.language,
          category: 'UTILITY',
          components: [
            {
              type: 'BODY',
              text: template.body,
              example: { body_text: [template.example] },
            },
          ],
        },
        { headers: this.authHeaders(accessToken), timeout: 30_000 },
      );
      return { status: response.data?.status as string | undefined };
    } catch (error) {
      throw this.toApiError(error, `template create wabaId=${wabaId}`);
    }
  }

  private authHeaders(accessToken: string) {
    return {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    };
  }

  private toApiError(error: unknown, context: string): MetaWhatsAppApiError {
    const axiosErr = error as AxiosError<{ error?: { message?: string; code?: number } }>;
    const status = axiosErr.response?.status;
    const message =
      axiosErr.response?.data?.error?.message || axiosErr.message || 'Meta API request failed';
    const code = axiosErr.response?.data?.error?.code;
    this.logger.warn(`Meta ${context} failed status=${status ?? 'n/a'} code=${code ?? 'n/a'}`);
    return new MetaWhatsAppApiError(message, status, code);
  }
}
