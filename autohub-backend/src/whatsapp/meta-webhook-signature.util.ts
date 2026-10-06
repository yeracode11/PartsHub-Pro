import { createHmac, timingSafeEqual } from 'crypto';

/** Проверка заголовка X-Hub-Signature-256 (HMAC-SHA256 тела запроса ключом App Secret). */
export function isValidMetaSignature(
  rawBody: Buffer | undefined,
  signatureHeader: string | undefined,
  appSecret: string,
): boolean {
  if (!rawBody || !signatureHeader || !appSecret) return false;

  const [scheme, received] = signatureHeader.split('=', 2);
  if (scheme !== 'sha256' || !received || !/^[0-9a-f]{64}$/i.test(received)) {
    return false;
  }

  const expected = createHmac('sha256', appSecret).update(rawBody).digest();
  return timingSafeEqual(expected, Buffer.from(received, 'hex'));
}
