import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export const QWEN_API_URL_ENV = 'QWEN_API_URL';
export const DEFAULT_QWEN_TIMEOUT_MS = 10_000;

@Injectable()
export class QwenConfig {
  constructor(private readonly configService: ConfigService) {}

  get apiBaseUrl(): string {
    return (
      this.configService.get<string>(QWEN_API_URL_ENV)?.trim() || ''
    ).replace(/\/$/, '');
  }

  get timeoutMs(): number {
    const raw = this.configService.get<string>('QWEN_API_TIMEOUT_MS');
    const parsed = raw ? Number.parseInt(raw, 10) : DEFAULT_QWEN_TIMEOUT_MS;
    return Number.isFinite(parsed) && parsed > 0
      ? parsed
      : DEFAULT_QWEN_TIMEOUT_MS;
  }
}
