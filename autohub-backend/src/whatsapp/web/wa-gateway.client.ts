import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { WaGatewayConfig } from './wa-gateway.config';
import type { WhatsAppWebState } from './whatsapp-web-instance.entity';

export interface GatewayInstanceStatus {
  instanceId: string;
  state: WhatsAppWebState;
  phone: string | null;
  qrDataUrl: string | null;
  reason: string | null;
  sentToday?: number;
  remainingToday?: number;
}

const ERROR_MESSAGES: Record<string, string> = {
  not_connected: 'WhatsApp не подключён. Отсканируйте QR в настройках.',
  not_on_whatsapp: 'Этот номер не зарегистрирован в WhatsApp.',
  per_day:
    'Достигнут суточный лимит сообщений с этого номера (защита от бана).',
  new_chats_per_day:
    'Достигнут лимит новых собеседников в сутки (защита от бана). Ответить тем, кто уже писал, можно.',
};

/** HTTP-клиент к whatsapp-gateway. Токены WhatsApp живут только в шлюзе. */
@Injectable()
export class WaGatewayClient {
  private readonly logger = new Logger(WaGatewayClient.name);

  constructor(private readonly config: WaGatewayConfig) {}

  start(instanceId: string) {
    return this.request<GatewayInstanceStatus>(
      'post',
      `/instances/${instanceId}/start`,
      undefined,
      30_000,
    );
  }

  status(instanceId: string) {
    return this.request<GatewayInstanceStatus>(
      'get',
      `/instances/${instanceId}`,
    );
  }

  logout(instanceId: string) {
    return this.request<{ ok: boolean }>(
      'post',
      `/instances/${instanceId}/logout`,
    );
  }

  sendText(instanceId: string, phone: string, text: string) {
    return this.request<{ messageId: string | null }>(
      'post',
      `/instances/${instanceId}/send-text`,
      { phone, text },
      // в шлюзе очередь с паузами: ждём дольше обычного
      120_000,
    );
  }

  sendFile(
    instanceId: string,
    phone: string,
    file: {
      url: string;
      fileName?: string;
      mimetype?: string;
      caption?: string;
    },
  ) {
    return this.request<{ messageId: string | null }>(
      'post',
      `/instances/${instanceId}/send-file`,
      { phone, ...file },
      120_000,
    );
  }

  private async request<T>(
    method: 'get' | 'post',
    path: string,
    data?: unknown,
    timeout = 15_000,
  ): Promise<T> {
    if (!this.config.isConfigured) {
      throw new HttpException(
        'WhatsApp-шлюз не настроен на сервере (WA_GATEWAY_URL / WA_GATEWAY_API_KEY)',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
    try {
      const res = await axios.request<T>({
        method,
        url: `${this.config.url}${path}`,
        data,
        timeout,
        headers: { 'x-api-key': this.config.apiKey },
      });
      return res.data;
    } catch (error) {
      const err = error as AxiosError<{ error?: string; message?: string }>;
      const status = err.response?.status;
      const code = err.response?.data?.error;
      if (status && status < 500 && code) {
        throw new HttpException(
          {
            error: code,
            message:
              ERROR_MESSAGES[code] ?? err.response?.data?.message ?? code,
          },
          status,
        );
      }
      this.logger.error(
        `gateway ${method.toUpperCase()} ${path} failed: ${err.message}`,
      );
      throw new HttpException(
        'WhatsApp-шлюз недоступен, попробуйте позже',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }
}
