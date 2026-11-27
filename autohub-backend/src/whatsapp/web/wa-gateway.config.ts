import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class WaGatewayConfig {
  constructor(private readonly config: ConfigService) {}

  /** http://whatsapp-gateway:3005 внутри docker-compose. */
  get url(): string {
    return (this.config.get<string>('WA_GATEWAY_URL')?.trim() || '').replace(
      /\/$/,
      '',
    );
  }

  get apiKey(): string {
    return this.config.get<string>('WA_GATEWAY_API_KEY')?.trim() || '';
  }

  /** Секрет подписи вебхуков шлюза (x-vinly-signature). */
  get webhookSecret(): string {
    return this.config.get<string>('WA_GATEWAY_WEBHOOK_SECRET')?.trim() || '';
  }

  /** Сколько минут бот молчит в чате после ответа менеджера. */
  get botPauseAfterManagerMinutes(): number {
    const raw = Number.parseInt(
      this.config.get<string>('WA_BOT_PAUSE_AFTER_MANAGER_MIN') ?? '',
      10,
    );
    return Number.isFinite(raw) && raw >= 0 ? raw : 120;
  }

  get isConfigured(): boolean {
    return Boolean(this.url && this.apiKey);
  }
}
