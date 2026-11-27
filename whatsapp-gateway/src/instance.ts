import fs from 'node:fs/promises';
import path from 'node:path';
import makeWASocket, {
  Browsers,
  DisconnectReason,
  fetchLatestBaileysVersion,
  getContentType,
  normalizeMessageContent,
  useMultiFileAuthState,
  type WAMessage,
  type WASocket,
} from 'baileys';
import QRCode from 'qrcode';
import type { Logger } from 'pino';
import type { SendLimits } from './config.js';
import { isIgnoredChat, phoneFromKey, phoneToJid } from './jid.js';
import { SendLimiter } from './send-limiter.js';
import type { InstanceState, WebhookSender } from './webhook.js';

const MAX_QR_WITHOUT_SCAN = 6; // ~2 минуты показа QR, потом стоп, чтобы не крутить вечно
const MAX_RECONNECT_DELAY_MS = 60_000;

export interface InstanceStatus {
  instanceId: string;
  state: InstanceState;
  phone: string | null;
  qrDataUrl: string | null;
  reason: string | null;
  sentToday: number;
  remainingToday: number;
}

export class NotReadyError extends Error {}
export class NotOnWhatsAppError extends Error {}

/** Один подключённый номер магазина (одно «связанное устройство»). */
export class WhatsAppInstance {
  private sock: WASocket | null = null;
  private state: InstanceState = 'stopped';
  private qr: string | null = null;
  private qrCount = 0;
  private phone: string | null = null;
  private reason: string | null = null;
  private reconnectAttempts = 0;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private stoppedByUser = false;
  private readonly limiter: SendLimiter;
  private knownChats = new Set<string>();
  private sentToday = 0;
  /** Был ли уже вход по QR (есть сохранённая сессия). */
  private registered = false;

  constructor(
    readonly instanceId: string,
    private readonly sessionsDir: string,
    limits: SendLimits,
    private readonly webhook: WebhookSender,
    private readonly log: Logger,
  ) {
    this.limiter = new SendLimiter(limits);
  }

  private get dir(): string {
    return path.join(this.sessionsDir, this.instanceId);
  }

  private get knownChatsFile(): string {
    return path.join(this.dir, 'known-chats.json');
  }

  async status(): Promise<InstanceStatus> {
    const remaining = this.limiter.remainingToday();
    return {
      instanceId: this.instanceId,
      state: this.state,
      phone: this.phone,
      qrDataUrl:
        this.state === 'qr' && this.qr ? await QRCode.toDataURL(this.qr, { margin: 1, width: 320 }) : null,
      reason: this.reason,
      sentToday: this.sentToday,
      remainingToday: remaining,
    };
  }

  async start(): Promise<void> {
    if (this.sock && (this.state === 'authorized' || this.state === 'qr' || this.state === 'starting')) {
      return;
    }
    this.stoppedByUser = false;
    this.qrCount = 0;
    this.reason = null;
    await fs.mkdir(this.dir, { recursive: true });
    await this.loadKnownChats();
    await this.connect();
  }

  private async connect(): Promise<void> {
    this.setState('starting');
    const { state, saveCreds } = await useMultiFileAuthState(this.dir);
    this.registered = Boolean(state.creds.registered);
    let version: [number, number, number] | undefined;
    try {
      ({ version } = await fetchLatestBaileysVersion());
    } catch {
      version = undefined; // возьмём встроенную версию
    }

    const sock = makeWASocket({
      auth: state,
      version,
      browser: Browsers.macOS('Vinly'),
      logger: this.log.child({ lib: 'baileys' }, { level: 'warn' }) as never,
      markOnlineOnConnect: false,
      syncFullHistory: false,
      generateHighQualityLinkPreview: false,
    });
    this.sock = sock;

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;
      if (qr) {
        this.qrCount += 1;
        if (this.qrCount > MAX_QR_WITHOUT_SCAN) {
          this.reason = 'qr_timeout';
          void this.stop(false);
          return;
        }
        this.qr = qr;
        this.setState('qr');
      }
      if (connection === 'open') {
        this.qr = null;
        this.registered = true;
        this.reconnectAttempts = 0;
        this.reason = null;
        const user = sock.user?.id?.split('@')[0]?.split(':')[0] ?? null;
        this.phone = user;
        this.setState('authorized');
      }
      if (connection === 'close') {
        const code = (lastDisconnect?.error as { output?: { statusCode?: number } } | undefined)
          ?.output?.statusCode;
        this.sock = null;
        void this.handleClose(code);
      }
    });

    sock.ev.on('messages.upsert', ({ messages, type }) => {
      if (type !== 'notify') return;
      for (const msg of messages) void this.handleMessage(msg);
    });
  }

  private async handleClose(code: number | undefined): Promise<void> {
    if (this.stoppedByUser) return;

    if (code === DisconnectReason.loggedOut || code === DisconnectReason.forbidden) {
      // Магазин отвязал устройство в телефоне или номер заблокирован.
      this.reason = code === DisconnectReason.forbidden ? 'banned' : 'logged_out_on_phone';
      await this.wipeSession();
      this.setState('logged_out');
      return;
    }
    if (code === DisconnectReason.connectionReplaced) {
      this.reason = 'connection_replaced';
      this.setState('stopped');
      return;
    }
    if (this.state === 'qr' && this.qrCount > MAX_QR_WITHOUT_SCAN) return;
    if (!this.registered && this.reconnectAttempts >= 5) {
      // QR так и не отсканировали, а связи нет: не крутим переподключение вечно.
      this.reason = 'connect_failed';
      await this.stop(false);
      return;
    }

    const delay =
      code === DisconnectReason.restartRequired
        ? 0
        : Math.min(MAX_RECONNECT_DELAY_MS, 2000 * 2 ** this.reconnectAttempts);
    this.reconnectAttempts += 1;
    this.setState('reconnecting');
    this.log.info({ instanceId: this.instanceId, code, delay }, 'reconnect scheduled');
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect().catch((err) =>
        this.log.error({ instanceId: this.instanceId, err: (err as Error).message }, 'reconnect failed'),
      );
    }, delay);
  }

  private async handleMessage(msg: WAMessage): Promise<void> {
    const key = msg.key;
    if (!key?.id || isIgnoredChat(key.remoteJid)) return;
    const phone = phoneFromKey(key as { remoteJid?: string; remoteJidAlt?: string });
    if (!phone) return;

    const content = normalizeMessageContent(msg.message);
    const contentType = getContentType(content) ?? 'unknown';
    if (contentType === 'protocolMessage' || contentType === 'reactionMessage' || contentType === 'senderKeyDistributionMessage') {
      return;
    }
    const text =
      content?.conversation ??
      content?.extendedTextMessage?.text ??
      content?.imageMessage?.caption ??
      content?.videoMessage?.caption ??
      content?.documentMessage?.caption ??
      '';

    this.rememberChat(phone);

    const ts = Number(msg.messageTimestamp ?? Math.floor(Date.now() / 1000));
    await this.webhook.send({
      type: 'message',
      instanceId: this.instanceId,
      messageId: key.id,
      phone,
      fromMe: Boolean(key.fromMe),
      pushName: msg.pushName ?? null,
      timestamp: ts,
      messageType: contentType === 'conversation' || contentType === 'extendedTextMessage' ? 'text' : String(contentType).replace(/Message$/, ''),
      text,
    });
  }

  async sendText(phone: string, text: string): Promise<{ messageId: string | null }> {
    return this.send(phone, { text });
  }

  async sendFile(
    phone: string,
    file: { url: string; fileName?: string; mimetype?: string; caption?: string },
  ): Promise<{ messageId: string | null }> {
    const mimetype = file.mimetype ?? 'application/octet-stream';
    if (mimetype.startsWith('image/')) {
      return this.send(phone, { image: { url: file.url }, caption: file.caption, mimetype });
    }
    return this.send(phone, {
      document: { url: file.url },
      fileName: file.fileName ?? 'file',
      mimetype,
      caption: file.caption,
    });
  }

  private async send(phone: string, content: Record<string, unknown>): Promise<{ messageId: string | null }> {
    const sock = this.sock;
    if (!sock || this.state !== 'authorized') {
      throw new NotReadyError('WhatsApp не подключён: отсканируйте QR в приложении');
    }
    const jid = phoneToJid(phone);
    const isNewChat = !this.knownChats.has(phone);
    if (isNewChat) {
      const [check] = (await sock.onWhatsApp(phone)) ?? [];
      if (!check?.exists) throw new NotOnWhatsAppError(`Номер ${phone} не зарегистрирован в WhatsApp`);
    }

    return this.limiter.schedule(phone, isNewChat, async () => {
      // «печатает…» перед ответом: так выглядит как живой человек
      await sock.sendPresenceUpdate('composing', jid).catch(() => undefined);
      await new Promise((r) => setTimeout(r, 800 + Math.floor(Math.random() * 1200)));
      await sock.sendPresenceUpdate('paused', jid).catch(() => undefined);
      const sent = await sock.sendMessage(jid, content as never);
      this.sentToday += 1;
      this.rememberChat(phone);
      return { messageId: sent?.key?.id ?? null };
    });
  }

  /** Отвязать устройство и удалить сессию. */
  async logout(): Promise<void> {
    this.stoppedByUser = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    try {
      await this.sock?.logout();
    } catch {
      // сокет мог быть уже закрыт
    }
    this.sock = null;
    await this.wipeSession();
    this.phone = null;
    this.reason = null;
    this.setState('logged_out');
  }

  /** Остановить без удаления сессии (например, при выключении шлюза). */
  async stop(byUser = true): Promise<void> {
    this.stoppedByUser = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.sock?.end(undefined);
    this.sock = null;
    this.qr = null;
    if (!byUser && !this.registered) await this.wipeSession();
    this.setState('stopped');
  }

  private setState(state: InstanceState): void {
    if (this.state === state && state !== 'qr') return;
    const changed = this.state !== state;
    this.state = state;
    if (changed) {
      this.log.info({ instanceId: this.instanceId, state, reason: this.reason }, 'state');
      void this.webhook.send({
        type: 'state',
        instanceId: this.instanceId,
        state,
        phone: this.phone,
        reason: this.reason ?? undefined,
      });
    }
  }

  private async wipeSession(): Promise<void> {
    await fs.rm(this.dir, { recursive: true, force: true });
    this.knownChats.clear();
  }

  private async loadKnownChats(): Promise<void> {
    try {
      const raw = await fs.readFile(this.knownChatsFile, 'utf8');
      this.knownChats = new Set(JSON.parse(raw) as string[]);
    } catch {
      this.knownChats = new Set();
    }
  }

  private rememberChat(phone: string): void {
    if (this.knownChats.has(phone)) return;
    this.knownChats.add(phone);
    fs.writeFile(this.knownChatsFile, JSON.stringify([...this.knownChats])).catch(() => undefined);
  }
}
