import { BadRequestException } from '@nestjs/common';

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

/** Сравнение номеров независимо от форматирования в БД. */
export function phoneDigitsKey(input: string): string {
  return input.replace(/\D/g, '').replace(/^8(\d{10})$/, '7$1');
}
