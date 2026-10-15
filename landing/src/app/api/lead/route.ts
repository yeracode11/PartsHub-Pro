import { NextResponse } from 'next/server';

export const runtime = 'nodejs';

const BUSINESS_TYPES = ['dismantler', 'service', 'shop', 'other'] as const;

type Lead = {
  name: string;
  phone: string;
  city: string;
  businessType: (typeof BUSINESS_TYPES)[number];
  comment: string;
};

function clean(v: unknown, max: number): string {
  return typeof v === 'string' ? v.trim().slice(0, max) : '';
}

function parse(body: unknown): Lead | null {
  if (!body || typeof body !== 'object') return null;
  const b = body as Record<string, unknown>;
  const phone = clean(b.phone, 20).replace(/\D/g, '');
  const name = clean(b.name, 100);
  const city = clean(b.city, 80);
  const businessType = clean(b.businessType, 20) as Lead['businessType'];
  if (name.length < 2 || city.length < 2) return null;
  if (!/^[78]?\d{10}$/.test(phone)) return null;
  if (!BUSINESS_TYPES.includes(businessType)) return null;
  return { name, phone: `+7${phone.slice(-10)}`, city, businessType, comment: clean(b.comment, 1000) };
}

/** Для логов: без имени и с замаскированным телефоном (персональные данные в лог не пишем). */
function safe(lead: Lead) {
  return { businessType: lead.businessType, city: lead.city, phone: `+7******${lead.phone.slice(-4)}` };
}

const BUSINESS_LABELS: Record<Lead['businessType'], string> = {
  dismantler: 'Авторазбор',
  service: 'СТО',
  shop: 'Магазин запчастей',
  other: 'Другое',
};

function esc(v: string): string {
  return v.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

/** Telegram настроен, если заданы токен бота и id чата (личного, группы или канала). */
function telegramConfig() {
  const { TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID } = process.env;
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) return null;
  return {
    token: TELEGRAM_BOT_TOKEN,
    chatId: TELEGRAM_CHAT_ID,
    apiBase: process.env.TELEGRAM_API_BASE || 'https://api.telegram.org',
  };
}

async function sendTelegram(cfg: NonNullable<ReturnType<typeof telegramConfig>>, lead: Lead, receivedAt: string) {
  const lines = [
    '<b>Заявка на демо Jolda CRM</b>',
    '',
    `Имя: <b>${esc(lead.name)}</b>`,
    `Телефон: <b>${esc(lead.phone)}</b>`,
    `Город: ${esc(lead.city)}`,
    `Тип бизнеса: ${BUSINESS_LABELS[lead.businessType]}`,
    `Комментарий: ${esc(lead.comment || '—')}`,
    '',
    `Получена: ${receivedAt}`,
  ];
  const res = await fetch(`${cfg.apiBase}/bot${cfg.token}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      chat_id: cfg.chatId,
      text: lines.join('\n'),
      parse_mode: 'HTML',
      disable_web_page_preview: true,
    }),
    signal: AbortSignal.timeout(8000),
  });
  // Адрес запроса содержит токен бота, поэтому в ошибку кладём только код ответа.
  if (!res.ok) throw new Error(`telegram ${res.status}`);
}

/**
 * Приём заявок. Каналы доставки (можно оба сразу): Telegram-бот (TELEGRAM_BOT_TOKEN,
 * TELEGRAM_CHAT_ID) и вебхук (LEAD_WEBHOOK_URL). Если не задан ни один: в разработке — заглушка с записью
 * в лог, в production — ошибка 503, чтобы заявка не терялась молча.
 */
export async function POST(req: Request) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false }, { status: 400 });
  }

  // Ловушка для ботов: настоящий пользователь это поле не видит.
  if (body && typeof body === 'object' && clean((body as Record<string, unknown>).website, 200)) {
    return NextResponse.json({ ok: true });
  }

  const lead = parse(body);
  if (!lead) return NextResponse.json({ ok: false }, { status: 422 });

  const receivedAt = new Date().toISOString();
  const payload = { ...lead, receivedAt, source: 'landing' };
  const webhook = process.env.LEAD_WEBHOOK_URL;
  const telegram = telegramConfig();

  if (!webhook && !telegram) {
    console.warn('[lead:stub] заявка не отправлена: не настроены TELEGRAM_* и LEAD_WEBHOOK_URL', JSON.stringify(safe(lead)));
    if (process.env.NODE_ENV === 'production') return NextResponse.json({ ok: false }, { status: 503 });
    return NextResponse.json({ ok: true, delivered: false });
  }

  const results = await Promise.allSettled([
    telegram ? sendTelegram(telegram, lead, receivedAt) : Promise.resolve(),
    webhook
      ? fetch(webhook, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(8000),
        }).then((res) => {
          if (!res.ok) throw new Error(`webhook ${res.status}`);
        })
      : Promise.resolve(),
  ]);
  const failed = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
  failed.forEach((r) => console.error('[lead] канал доставки не сработал:', (r.reason as Error).message, JSON.stringify(safe(lead))));
  // Заявка считается доставленной, если сработал хотя бы один из настроенных каналов.
  const channels = Number(Boolean(telegram)) + Number(Boolean(webhook));
  if (failed.length >= channels) return NextResponse.json({ ok: false }, { status: 502 });
  return NextResponse.json({ ok: true, delivered: true });
}
