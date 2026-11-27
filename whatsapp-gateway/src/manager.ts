import fs from 'node:fs/promises';
import path from 'node:path';
import type { Logger } from 'pino';
import type { GatewayConfig } from './config.js';
import { isValidInstanceId } from './jid.js';
import { WhatsAppInstance } from './instance.js';
import type { WebhookSender } from './webhook.js';

export class InstanceManager {
  private readonly instances = new Map<string, WhatsAppInstance>();

  constructor(
    private readonly config: GatewayConfig,
    private readonly webhook: WebhookSender,
    private readonly log: Logger,
  ) {}

  get(instanceId: string): WhatsAppInstance | undefined {
    return this.instances.get(instanceId);
  }

  getOrCreate(instanceId: string): WhatsAppInstance {
    if (!isValidInstanceId(instanceId)) throw new Error('invalid instanceId');
    let inst = this.instances.get(instanceId);
    if (!inst) {
      inst = new WhatsAppInstance(
        instanceId,
        this.config.sessionsDir,
        this.config.limits,
        this.webhook,
        this.log,
      );
      this.instances.set(instanceId, inst);
    }
    return inst;
  }

  /** После перезапуска шлюза поднимаем все сессии, у которых есть сохранённый вход. */
  async restoreAll(): Promise<number> {
    await fs.mkdir(this.config.sessionsDir, { recursive: true });
    const entries = await fs.readdir(this.config.sessionsDir, { withFileTypes: true });
    let restored = 0;
    for (const entry of entries) {
      if (!entry.isDirectory() || !isValidInstanceId(entry.name)) continue;
      const creds = path.join(this.config.sessionsDir, entry.name, 'creds.json');
      try {
        await fs.access(creds);
      } catch {
        continue;
      }
      // Разносим подключения во времени, чтобы не стучаться всеми сразу.
      await new Promise((r) => setTimeout(r, 1500));
      this.getOrCreate(entry.name)
        .start()
        .catch((err) => this.log.error({ instanceId: entry.name, err: (err as Error).message }, 'restore failed'));
      restored += 1;
    }
    return restored;
  }

  async stopAll(): Promise<void> {
    await Promise.all([...this.instances.values()].map((i) => i.stop()));
  }
}
