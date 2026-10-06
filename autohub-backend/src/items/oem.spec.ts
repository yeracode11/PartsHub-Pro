import { normalizeOem } from './oem';

describe('normalizeOem', () => {
  it.each(['04465-12345', '0446512345', '04465 12345', ' 04465.12345 '])(
    '%s → 0446512345',
    (input) => {
      expect(normalizeOem(input)).toBe('0446512345');
    },
  );

  it('приводит к верхнему регистру и убирает разделители', () => {
    expect(normalizeOem('a2c-53/41 m')).toBe('A2C5341M');
  });

  it('понимает номер, набранный в русской раскладке', () => {
    expect(normalizeOem('А2С 5341')).toBe('A2C5341');
  });

  it('пустое значение не превращает в номер', () => {
    expect(normalizeOem(' - ')).toBeNull();
    expect(normalizeOem(null)).toBeNull();
    expect(normalizeOem(42)).toBeNull();
  });
});
