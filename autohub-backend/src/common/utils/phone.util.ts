import { BadRequestException } from '@nestjs/common';

/** US/CA: +1 и 10 цифр национального номера. */
export function normalizeUsPhone(input: string): string {
  const digits = input.replace(/\D/g, '');

  let normalized = digits;
  if (normalized.length === 11 && normalized.startsWith('1')) {
    // ok
  } else if (normalized.length === 10) {
    normalized = `1${normalized}`;
  } else {
    throw new BadRequestException(
      'Введите корректный номер телефона (+1)',
    );
  }

  if (normalized.length !== 11 || !normalized.startsWith('1')) {
    throw new BadRequestException(
      'Введите корректный номер телефона (+1)',
    );
  }

  return `+${normalized}`;
}

/** Нормализует номер Казахстана (+7, 11 цифр) в формат E.164: +77771234567 */
export function normalizeKzPhone(input: string): string {
  const digits = input.replace(/\D/g, '');

  let normalized = digits;
  if (normalized.startsWith('8') && normalized.length === 11) {
    normalized = `7${normalized.slice(1)}`;
  } else if (normalized.startsWith('7') && normalized.length === 11) {
    // ok
  } else if (normalized.length === 10) {
    normalized = `7${normalized}`;
  }

  if (normalized.length !== 11 || !normalized.startsWith('7')) {
    throw new BadRequestException('Введите корректный номер телефона Казахстана');
  }

  return `+${normalized}`;
}

/** E.164: Казахстан (+7) или US/CA (+1). */
export function normalizePhoneE164(input: string): string {
  const trimmed = input.trim();
  const digits = trimmed.replace(/\D/g, '');

  if (trimmed.startsWith('+1') || (digits.startsWith('1') && digits.length === 11)) {
    return normalizeUsPhone(trimmed);
  }

  return normalizeKzPhone(trimmed);
}

/** Сравнение номеров независимо от форматирования в БД. */
export function phoneDigitsKey(input: string): string {
  return input.replace(/\D/g, '').replace(/^8(\d{10})$/, '7$1');
}
