import { BadRequestException } from '@nestjs/common';
import { parseItemCatalogInput, parseItemListQuery } from './item-catalog';

describe('parseItemCatalogInput', () => {
  const parse = (data: unknown, canEditCost = true) =>
    parseItemCatalogInput(data, { canEditCost });

  it('пропускает только известные поля', () => {
    const { fields } = parse({
      name: 'Фара',
      donorTitle: 'Toyota',
      createdAt: '2026-01-01',
      oemNormalized: 'HACK',
    });
    expect(fields).toEqual({ name: 'Фара' });
  });

  it('пустой OEM очищает и нормализованное значение', () => {
    expect(parse({ oem: '  ' }).fields).toEqual({
      oem: null,
      oemNormalized: null,
    });
  });

  it('закупочная цена — неотрицательная сумма', () => {
    expect(parse({ purchaseCost: '1500.5' }).fields.purchaseCost).toBe(
      '1500.50',
    );
    expect(() => parse({ purchaseCost: -1 })).toThrow(BadRequestException);
  });

  it('отклоняет неизвестный статус и тип аналога', () => {
    expect(() => parse({ status: 'sold' })).toThrow(BadRequestException);
    expect(() =>
      parse({ crossReferences: [{ oem: '123', type: 'any' }] }),
    ).toThrow(BadRequestException);
  });

  it('проверяет годы применимости', () => {
    expect(() =>
      parse({
        compatibility: [
          { make: 'Toyota', model: 'Camry', yearFrom: 2024, yearTo: 2018 },
        ],
      }),
    ).toThrow('«Год с» позже');
    expect(() =>
      parse({
        compatibility: [{ make: 'Toyota', model: 'Camry', yearFrom: 1800 }],
      }),
    ).toThrow(BadRequestException);
  });

  it('принимает только http(s)-ссылки на видео', () => {
    expect(parse({ videos: ['https://youtu.be/x'] }).fields.videos).toEqual([
      'https://youtu.be/x',
    ]);
    expect(() => parse({ videos: ['javascript:alert(1)'] })).toThrow(
      BadRequestException,
    );
  });

  it('не трогает связи, если их не прислали', () => {
    const input = parse({ name: 'Фара' });
    expect(input.crossReferences).toBeUndefined();
    expect(input.compatibility).toBeUndefined();
  });
});

describe('parseItemListQuery', () => {
  it('ограничивает размер страницы и не принимает отрицательный offset', () => {
    expect(parseItemListQuery({ limit: '0', offset: '-5' })).toMatchObject({
      limit: 1,
      offset: 0,
    });
  });

  it('игнорирует неизвестный статус', () => {
    expect(parseItemListQuery({ status: 'deleted' }).status).toBeUndefined();
  });
});
