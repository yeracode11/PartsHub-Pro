import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export const META_WEBHOOK_VERIFY_ENV_KEY = 'WHATSAPP_WEBHOOK_VERIFY_TOKEN';

@Injectable()
export class MetaWhatsAppConfig {
  constructor(private readonly configService: ConfigService) {}

  get apiVersion(): string {
    return (
      this.configService.get<string>('META_WHATSAPP_API_VERSION')?.trim() ||
      'v26.0'
    );
  }

  get apiUrl(): string {
    return (
      this.configService.get<string>('META_WHATSAPP_API_URL')?.trim() ||
      'https://graph.facebook.com'
    ).replace(/\/$/, '');
  }

  /**
   * Канонический verify token — только WHATSAPP_WEBHOOK_VERIFY_TOKEN.
   * (META_WHATSAPP_VERIFY_TOKEN / WHATSAPP_VERIFY_TOKEN не используются для verify.)
   */
  get verifyToken(): string {
    return this.resolveVerifyToken().value;
  }

  resolveVerifyToken(): {
    value: string;
    envKey: typeof META_WEBHOOK_VERIFY_ENV_KEY | null;
  } {
    const webhook = this.configService
      .get<string>(META_WEBHOOK_VERIFY_ENV_KEY)
      ?.trim();
    if (webhook) {
      return { value: webhook, envKey: META_WEBHOOK_VERIFY_ENV_KEY };
    }
    return { value: '', envKey: null };
  }

  /** Fallback для dev/single-tenant, пока нет строки в whatsapp_connections. */
  get fallbackAccessToken(): string {
    return (
      this.configService.get<string>('META_WHATSAPP_ACCESS_TOKEN')?.trim() ||
      ''
    );
  }

  get fallbackPhoneNumberId(): string {
    return (
      this.configService.get<string>('META_WHATSAPP_PHONE_NUMBER_ID')?.trim() ||
      ''
    );
  }

  messagesUrl(phoneNumberId: string): string {
    return `${this.apiUrl}/${this.apiVersion}/${phoneNumberId}/messages`;
  }
}
