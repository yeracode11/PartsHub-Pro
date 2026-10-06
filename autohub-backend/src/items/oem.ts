/** Кириллица, похожая на латиницу: номер, набранный в русской раскладке, должен находиться. */
const LOOKALIKES: Record<string, string> = {
  А: 'A',
  В: 'B',
  Е: 'E',
  К: 'K',
  М: 'M',
  Н: 'H',
  О: 'O',
  Р: 'P',
  С: 'C',
  Т: 'T',
  У: 'Y',
  Х: 'X',
};

/**
 * Каталожный номер для поиска: верхний регистр, только латиница и цифры.
 * «04465-12345», «0446512345» и «04465 12345» дают одно значение.
 */
export function normalizeOem(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value
    .toUpperCase()
    .replace(/[АВЕКМНОРСТУХ]/g, (char) => LOOKALIKES[char])
    .replace(/[^A-Z0-9]/g, '');
  return normalized || null;
}
