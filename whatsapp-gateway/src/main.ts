import { pino } from 'pino';
import { loadConfig } from './config.js';
import { InstanceManager } from './manager.js';
import { createServer } from './server.js';
import { WebhookSender } from './webhook.js';

const log = pino({ level: process.env.LOG_LEVEL ?? 'info' });
const config = loadConfig();

if (!config.apiKey) {
  log.fatal('GATEWAY_API_KEY не задан — шлюз не запустится без ключа');
  process.exit(1);
}
if (!config.webhookUrl) log.warn('BACKEND_WEBHOOK_URL не задан — входящие никуда не уйдут');
if (!config.webhookSecret) log.warn('GATEWAY_WEBHOOK_SECRET не задан — вебхуки без подписи');

const webhook = new WebhookSender(config.webhookUrl, config.webhookSecret, log);
const manager = new InstanceManager(config, webhook, log);
const app = createServer(manager, config.apiKey, log);

const server = app.listen(config.port, () => {
  log.info({ port: config.port, sessionsDir: config.sessionsDir }, 'whatsapp-gateway started');
  manager
    .restoreAll()
    .then((n) => log.info({ restored: n }, 'sessions restored'))
    .catch((err) => log.error({ err: (err as Error).message }, 'restore failed'));
});

async function shutdown() {
  log.info('shutting down');
  server.close();
  await manager.stopAll();
  process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
