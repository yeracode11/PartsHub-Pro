import { timingSafeEqual } from 'node:crypto';
import express, { type NextFunction, type Request, type Response } from 'express';
import type { Logger } from 'pino';
import { isValidInstanceId, normalizePhone } from './jid.js';
import { NotOnWhatsAppError, NotReadyError } from './instance.js';
import type { InstanceManager } from './manager.js';
import { SendLimitError } from './send-limiter.js';

function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

type AsyncHandler = (req: Request, res: Response) => Promise<void>;

/** Express 4 не ловит ошибки async-обработчиков сам — передаём их в next(). */
const wrap =
  (fn: AsyncHandler) =>
  (req: Request, res: Response, next: NextFunction): void => {
    fn(req, res).catch(next);
  };

export function createServer(manager: InstanceManager, apiKey: string, log: Logger) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '256kb' }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  // Всё остальное — только для бэкенда Vinly.
  app.use((req: Request, res: Response, next: NextFunction) => {
    const key = req.header('x-api-key') ?? '';
    if (!apiKey || !safeEqual(key, apiKey)) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    next();
  });

  app.param('id', (req, res, next, id: string) => {
    if (!isValidInstanceId(id)) {
      res.status(400).json({ error: 'invalid instance id' });
      return;
    }
    next();
  });

  app.post('/instances/:id/start', wrap(async (req, res) => {
    const inst = manager.getOrCreate(req.params.id);
    await inst.start();
    // даём Baileys пару секунд выдать первый QR
    await new Promise((r) => setTimeout(r, 2500));
    res.json(await inst.status());
  }));

  app.get('/instances/:id', wrap(async (req, res) => {
    const inst = manager.get(req.params.id);
    if (!inst) {
      res.json({ instanceId: req.params.id, state: 'stopped', phone: null, qrDataUrl: null, reason: null });
      return;
    }
    res.json(await inst.status());
  }));

  app.post('/instances/:id/logout', wrap(async (req, res) => {
    const inst = manager.get(req.params.id);
    if (inst) await inst.logout();
    res.json({ ok: true });
  }));

  app.post('/instances/:id/send-text', wrap(async (req, res) => {
    const phone = normalizePhone(req.body?.phone);
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    if (!phone || !text || text.length > 4096) {
      res.status(400).json({ error: 'phone and text (≤4096) are required' });
      return;
    }
    const inst = manager.get(req.params.id);
    if (!inst) {
      res.status(409).json({ error: 'not_connected' });
      return;
    }
    res.json(await inst.sendText(phone, text));
  }));

  app.post('/instances/:id/send-file', wrap(async (req, res) => {
    const phone = normalizePhone(req.body?.phone);
    const url = typeof req.body?.url === 'string' ? req.body.url : '';
    if (!phone || !/^https?:\/\//.test(url)) {
      res.status(400).json({ error: 'phone and http(s) url are required' });
      return;
    }
    const inst = manager.get(req.params.id);
    if (!inst) {
      res.status(409).json({ error: 'not_connected' });
      return;
    }
    res.json(
      await inst.sendFile(phone, {
        url,
        fileName: req.body?.fileName,
        mimetype: req.body?.mimetype,
        caption: req.body?.caption,
      }),
    );
  }));

  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof NotReadyError) {
      res.status(409).json({ error: 'not_connected', message: err.message });
      return;
    }
    if (err instanceof NotOnWhatsAppError) {
      res.status(422).json({ error: 'not_on_whatsapp', message: err.message });
      return;
    }
    if (err instanceof SendLimitError) {
      res.status(429).json({ error: err.code, message: err.message });
      return;
    }
    log.error({ err: (err as Error)?.message }, 'request failed');
    res.status(500).json({ error: 'internal' });
  });

  return app;
}
