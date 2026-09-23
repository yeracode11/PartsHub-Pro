import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

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

  /** Verify token для Meta webhook (GET hub.verify_token). */
  get verifyToken(): string {
    const meta = this.configService.get<string>('META_WHATSAPP_VERIFY_TOKEN');
    if (meta?.trim()) return meta.trim();

    const legacy =
      this.configService.get<string>('WHATSAPP_VERIFY_TOKEN') ||
      this.configService.get<string>('WHATSAPP_WEBHOOK_VERIFY_TOKEN');
    return legacy?.trim() || '';
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
