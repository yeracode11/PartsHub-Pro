/**
 * Нормализация WhatsApp ID / номера для поля Graph API `to`.
 * Без добавления country prefix — только цифры из входной строки.
 */
export function toMetaWhatsAppDigits(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (!digits) {
    throw new Error('WhatsApp recipient is empty after normalization');
  }
  return digits;
}
