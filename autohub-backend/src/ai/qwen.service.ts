import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { QwenConfig } from './qwen.config';
import { QwenIntentResult } from './qwen-intent.types';
import { parseQwenIntentResponse } from './qwen-intent.validator';

@Injectable()
export class QwenService {
  private readonly logger = new Logger(QwenService.name);

  constructor(private readonly config: QwenConfig) {}

  /**
   * NLP intent parse. Только текст пользователя — без tenant/token/БД.
   */
  async parseIntent(
    message: string,
    language?: string,
  ): Promise<QwenIntentResult | null> {
    const baseUrl = this.config.apiBaseUrl;
    if (!baseUrl) {
      this.logger.warn('QWEN parse skipped: QWEN_API_URL is not configured');
      return null;
    }

    const trimmed = message?.trim();
    if (!trimmed) {
      this.logger.warn('QWEN parse skipped: empty message');
      return null;
    }

    const url = `${baseUrl}/v1/intent`;
    const payload = {
      message: trimmed,
      language: language?.trim() || 'auto',
    };

    try {
      const response = await axios.post(url, payload, {
        timeout: this.config.timeoutMs,
        headers: { 'Content-Type': 'application/json' },
        validateStatus: () => true,
      });

      if (response.status < 200 || response.status >= 300) {
        this.logger.warn(
          `QWEN HTTP error status=${response.status} url=${url}`,
        );
        return null;
      }

      let data: unknown = response.data;
      if (typeof data === 'string') {
        try {
          data = JSON.parse(data);
        } catch {
          this.logger.warn('QWEN invalid JSON string response');
          return null;
        }
      }

      const parsed = parseQwenIntentResponse(data);
      if (!parsed) {
        this.logger.warn('QWEN response failed validation');
        return null;
      }

      return parsed;
    } catch (error) {
      this.logTransportError(error, url);
      return null;
    }
  }

  private logTransportError(error: unknown, url: string): void {
    const axiosErr = error as AxiosError;
    if (axiosErr.code === 'ECONNABORTED') {
      this.logger.warn(`QWEN timeout url=${url} ms=${this.config.timeoutMs}`);
      return;
    }
    if (axiosErr.code === 'ECONNREFUSED' || axiosErr.code === 'ENOTFOUND') {
      this.logger.warn(`QWEN connection error code=${axiosErr.code} url=${url}`);
      return;
    }
    this.logger.warn(
      `QWEN request failed url=${url}: ${
        axiosErr.message || (error instanceof Error ? error.message : String(error))
      }`,
    );
  }
}
