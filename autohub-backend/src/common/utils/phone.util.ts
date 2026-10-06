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

/** Код страны и длина национального номера: СНГ и США. */
const PHONE_COUNTRIES: Array<{ dial: string; national: number }> = [
  { dial: '998', national: 9 },
  { dial: '996', national: 9 },
  { dial: '994', national: 9 },
  { dial: '993', national: 8 },
  { dial: '992', national: 9 },
  { dial: '375', national: 9 },
  { dial: '374', national: 8 },
  { dial: '373', national: 8 },
  { dial: '7', national: 10 },
  { dial: '1', national: 10 },
];

/** E.164 для стран СНГ и США. */
export function normalizePhoneE164(input: string): string {
  let digits = input.trim().replace(/\D/g, '');
  if (!digits) {
    throw new BadRequestException('Введите корректный номер телефона');
  }

  if (digits.length === 11 && digits.startsWith('8')) {
    digits = `7${digits.slice(1)}`;
  }

  const matched = [...PHONE_COUNTRIES]
    .sort((a, b) => b.dial.length - a.dial.length)
    .find(
      (country) =>
        digits.startsWith(country.dial) &&
        digits.length === country.dial.length + country.national,
    );

  if (!matched) {
    throw new BadRequestException('Введите корректный номер телефона');
  }

  return `+${digits}`;
}

/** Сравнение номеров независимо от форматирования в БД. */
export function phoneDigitsKey(input: string): string {
  return input.replace(/\D/g, '').replace(/^8(\d{10})$/, '7$1');
}
