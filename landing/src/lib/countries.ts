/** Страны для поля телефона: код набора, маска по группам цифр национального номера. Общий для формы и API. */
export type Country = {
  code: string;
  name: string;
  dial: string;
  /** Длины групп цифр национального номера: [3, 3, 2, 2] → «701 234 56 78». */
  groups: number[];
  placeholder: string;
};

export const countries: Country[] = [
  { code: 'KZ', name: 'Казахстан', dial: '7', groups: [3, 3, 2, 2], placeholder: '701 234 56 78' },
  { code: 'RU', name: 'Россия', dial: '7', groups: [3, 3, 2, 2], placeholder: '912 345 67 89' },
  { code: 'UZ', name: 'Узбекистан', dial: '998', groups: [2, 3, 2, 2], placeholder: '90 123 45 67' },
  { code: 'KG', name: 'Кыргызстан', dial: '996', groups: [3, 3, 3], placeholder: '700 123 456' },
  { code: 'BY', name: 'Беларусь', dial: '375', groups: [2, 3, 2, 2], placeholder: '29 123 45 67' },
  { code: 'AM', name: 'Армения', dial: '374', groups: [2, 6], placeholder: '77 123456' },
  { code: 'AZ', name: 'Азербайджан', dial: '994', groups: [2, 3, 2, 2], placeholder: '50 123 45 67' },
  { code: 'TJ', name: 'Таджикистан', dial: '992', groups: [2, 3, 2, 2], placeholder: '93 123 45 67' },
  { code: 'MD', name: 'Молдова', dial: '373', groups: [3, 2, 3], placeholder: '621 23 456' },
  { code: 'TM', name: 'Туркменистан', dial: '993', groups: [2, 6], placeholder: '65 123456' },
];

export const defaultCountry = countries[0];

export function findCountry(code: unknown): Country | undefined {
  return countries.find((c) => c.code === code);
}

export function maxDigits(c: Country): number {
  return c.groups.reduce((a, b) => a + b, 0);
}

/** Раскладывает цифры по маске страны. */
export function formatNational(digits: string, c: Country): string {
  const parts: string[] = [];
  let pos = 0;
  for (const g of c.groups) {
    if (pos >= digits.length) break;
    parts.push(digits.slice(pos, pos + g));
    pos += g;
  }
  return parts.join(' ');
}

/**
 * Оставляет только цифры национального номера: отрезает код страны (и «8» для +7),
 * если номер вставили целиком, и обрезает по длине маски.
 */
export function normalizeNational(raw: string, c: Country): string {
  let d = raw.replace(/\D/g, '');
  const max = maxDigits(c);
  if (d.length > max) {
    if (d.startsWith(c.dial)) d = d.slice(c.dial.length);
    else if (c.dial === '7' && d.startsWith('8')) d = d.slice(1);
  }
  return d.slice(0, max);
}
