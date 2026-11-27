import { createHmac } from 'node:crypto';
import type { Logger } from 'pino';

export type GatewayEvent =
  | {
      type: 'state';
      instanceId: string;
      state: InstanceState;
      phone?: string | null;
      reason?: string;
    }
  | {
      type: 'message';
      instanceId: string;
      messageId: string;
      phone: string;
      fromMe: boolean;
      pushName?: string | null;
      timestamp: number;
      messageType: string;
      text: string;
    };

export type InstanceState =
  | 'starting'
  | 'qr'
  | 'authorized'
  | 'reconnecting'
  | 'logged_out'
  | 'stopped';

export function signBody(body: string, secret: string): string {
  return `sha256=${createHmac('sha256', secret).update(body).digest('hex')}`;
}

/** Отправка событий в бэкенд с повторами. Падение бэкенда не роняет шлюз. */
export class WebhookSender {
  constructor(
    private readonly url: string,
    private readonly secret: string,
    private readonly log: Logger,
  ) {}

  async send(event: GatewayEvent): Promise<void> {
    if (!this.url) return;
    const body = JSON.stringify(event);
    const headers: Record<string, string> = { 'content-type': 'application/json' };
    if (this.secret) headers['x-vinly-signature'] = signBody(body, this.secret);

    for (let attempt = 1; attempt <= 4; attempt++) {
      try {
        const res = await fetch(this.url, {
          method: 'POST',
          headers,
          body,
          signal: AbortSignal.timeout(15_000),
        });
        if (res.ok) return;
        if (res.status >= 400 && res.status < 500) {
          this.log.warn({ status: res.status, type: event.type }, 'webhook rejected');
          return;
        }
      } catch (error) {
        this.log.warn({ attempt, err: (error as Error).message }, 'webhook failed');
      }
      await new Promise((r) => setTimeout(r, 1000 * 2 ** attempt));
    }
    this.log.error({ type: event.type, instanceId: event.instanceId }, 'webhook dropped');
  }
}
