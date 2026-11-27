import path from 'node:path';

function int(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  const n = raw ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

export interface SendLimits {
  /** Минимальная пауза между исходящими одного номера, мс. */
  minDelayMs: number;
  /** Случайная добавка к паузе, мс (чтобы ритм не был машинным). */
  jitterMs: number;
  /** Не больше N исходящих в минуту с одного номера. */
  maxPerMinute: number;
  /** Не больше N исходящих в сутки с одного номера. */
  maxPerDay: number;
  /** Не больше N новых собеседников в сутки (кому номер раньше не писал). */
  maxNewChatsPerDay: number;
}

export interface GatewayConfig {
  port: number;
  /** Ключ, которым бэкенд подписывает запросы к шлюзу (заголовок x-api-key). */
  apiKey: string;
  /** Куда слать события: https://backend/webhooks/wa-gateway */
  webhookUrl: string;
  /** Секрет HMAC-SHA256 для заголовка x-vinly-signature. */
  webhookSecret: string;
  sessionsDir: string;
  limits: SendLimits;
}

export function loadConfig(): GatewayConfig {
  return {
    port: int('PORT', 3005),
    apiKey: process.env.GATEWAY_API_KEY?.trim() ?? '',
    webhookUrl: process.env.BACKEND_WEBHOOK_URL?.trim() ?? '',
    webhookSecret: process.env.GATEWAY_WEBHOOK_SECRET?.trim() ?? '',
    sessionsDir: path.resolve(process.env.SESSIONS_DIR?.trim() || './sessions'),
    limits: {
      minDelayMs: int('SEND_MIN_DELAY_MS', 3000),
      jitterMs: int('SEND_JITTER_MS', 2000),
      maxPerMinute: int('SEND_MAX_PER_MINUTE', 12),
      maxPerDay: int('SEND_MAX_PER_DAY', 500),
      maxNewChatsPerDay: int('SEND_MAX_NEW_CHATS_PER_DAY', 30),
    },
  };
}
