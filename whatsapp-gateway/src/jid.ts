/**
 * Идентификатор инстанса = organizationId магазина (uuid).
 * Строгая проверка: он же имя папки сессии, никаких ../
 */
const INSTANCE_ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isValidInstanceId(id: unknown): id is string {
  return typeof id === 'string' && INSTANCE_ID_RE.test(id);
}

/** Номер в любом виде (+7 701 123-45-67, 87011234567) → только цифры, 8xxx → 7xxx для KZ/RU. */
export function normalizePhone(input: unknown): string | null {
  if (typeof input !== 'string' && typeof input !== 'number') return null;
  let digits = String(input).replace(/\D/g, '');
  if (digits.length === 11 && digits.startsWith('8')) digits = `7${digits.slice(1)}`;
  if (digits.length < 10 || digits.length > 15) return null;
  return digits;
}

export function phoneToJid(phone: string): string {
  return `${phone}@s.whatsapp.net`;
}

/** Личный чат с телефоном (не группа, не статус, не канал). */
export function isPersonalPhoneJid(jid: string | null | undefined): jid is string {
  return typeof jid === 'string' && jid.endsWith('@s.whatsapp.net');
}

export function isIgnoredChat(jid: string | null | undefined): boolean {
  if (!jid) return true;
  return (
    jid.endsWith('@g.us') ||
    jid.endsWith('@broadcast') ||
    jid.endsWith('@newsletter') ||
    jid === 'status@broadcast'
  );
}

/**
 * С 2025 WhatsApp может присылать собеседника как LID (xxx@lid) вместо номера.
 * Номер тогда лежит в remoteJidAlt. Берём тот, что с номером.
 */
export function phoneFromKey(key: {
  remoteJid?: string | null;
  remoteJidAlt?: string | null;
}): string | null {
  const candidates = [key.remoteJid, key.remoteJidAlt];
  for (const jid of candidates) {
    if (isPersonalPhoneJid(jid)) {
      const user = jid.split('@')[0].split(':')[0];
      return normalizePhone(user);
    }
  }
  return null;
}
