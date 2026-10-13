import { businessMonthStart } from './dashboard.service';

describe('businessMonthStart', () => {
  const original = process.env.APP_TIME_ZONE;
  afterEach(() => {
    process.env.APP_TIME_ZONE = original;
  });

  it('берёт начало месяца по Алматы (UTC+5), а не по UTC сервера', () => {
    process.env.APP_TIME_ZONE = 'Asia/Almaty';
    // 1 ноября 02:00 по Алматы — это ещё 31 октября по UTC.
    expect(businessMonthStart(new Date('2026-10-31T21:00:00Z')).toISOString()).toBe(
      '2026-10-31T19:00:00.000Z',
    );
    expect(businessMonthStart(new Date('2026-10-13T12:00:00Z')).toISOString()).toBe(
      '2026-09-30T19:00:00.000Z',
    );
  });

  it('в UTC совпадает с полуночью первого числа', () => {
    process.env.APP_TIME_ZONE = 'UTC';
    expect(businessMonthStart(new Date('2026-03-15T10:00:00Z')).toISOString()).toBe(
      '2026-03-01T00:00:00.000Z',
    );
  });
});
