import type { SendLimits } from './config.js';

export class SendLimitError extends Error {
  constructor(
    message: string,
    readonly code: 'per_day' | 'new_chats_per_day',
  ) {
    super(message);
  }
}

/**
 * Защита номера магазина от бана: очередь с паузами и суточные лимиты.
 * Все исходящие одного номера идут строго по одному.
 */
export class SendLimiter {
  private queue: Promise<unknown> = Promise.resolve();
  private lastSentAt = 0;
  private minuteWindow: number[] = [];
  private day = '';
  private sentToday = 0;
  private newChatsToday = new Set<string>();

  constructor(
    private readonly limits: SendLimits,
    private readonly now: () => number = Date.now,
    private readonly sleep: (ms: number) => Promise<void> = (ms) =>
      new Promise((r) => setTimeout(r, ms)),
    private readonly random: () => number = Math.random,
  ) {}

  /** Сколько ещё можно отправить сегодня. */
  remainingToday(): number {
    this.rollDay();
    return Math.max(0, this.limits.maxPerDay - this.sentToday);
  }

  /**
   * Поставить отправку в очередь.
   * isNewChat — номеру ещё не писали и он сам не писал (холодный контакт).
   */
  schedule<T>(recipient: string, isNewChat: boolean, send: () => Promise<T>): Promise<T> {
    const run = async (): Promise<T> => {
      this.rollDay();
      if (this.sentToday >= this.limits.maxPerDay) {
        throw new SendLimitError(
          `Достигнут суточный лимит ${this.limits.maxPerDay} сообщений с этого номера`,
          'per_day',
        );
      }
      if (
        isNewChat &&
        !this.newChatsToday.has(recipient) &&
        this.newChatsToday.size >= this.limits.maxNewChatsPerDay
      ) {
        throw new SendLimitError(
          `Достигнут лимит ${this.limits.maxNewChatsPerDay} новых собеседников в сутки`,
          'new_chats_per_day',
        );
      }

      await this.waitForSlot();
      const result = await send();

      const t = this.now();
      this.lastSentAt = t;
      this.minuteWindow.push(t);
      this.sentToday += 1;
      if (isNewChat) this.newChatsToday.add(recipient);
      return result;
    };

    const next = this.queue.then(run, run);
    this.queue = next.catch(() => undefined);
    return next;
  }

  private async waitForSlot(): Promise<void> {
    const t = this.now();
    const pause =
      this.limits.minDelayMs + Math.floor(this.random() * (this.limits.jitterMs + 1));
    let waitMs = Math.max(0, this.lastSentAt + pause - t);

    this.minuteWindow = this.minuteWindow.filter((ts) => t - ts < 60_000);
    if (this.minuteWindow.length >= this.limits.maxPerMinute) {
      const oldest = this.minuteWindow[0];
      waitMs = Math.max(waitMs, oldest + 60_000 - t);
    }
    if (this.lastSentAt === 0 && this.minuteWindow.length === 0) waitMs = 0;
    if (waitMs > 0) await this.sleep(waitMs);
  }

  private rollDay(): void {
    const d = new Date(this.now()).toISOString().slice(0, 10);
    if (d !== this.day) {
      this.day = d;
      this.sentToday = 0;
      this.newChatsToday.clear();
    }
  }
}
