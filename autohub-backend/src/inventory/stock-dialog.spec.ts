import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import 'reflect-metadata';
import { parseQwenIntentResponse } from '../ai/qwen-intent.validator';
import { QwenIntentResult } from '../ai/qwen-intent.types';
import { Item } from '../items/entities/item.entity';
import { foldText, itemMatchesStockIntent } from './part-search-keywords.util';
import { StockService } from './stock.service';

const blank = {
  model: null,
  generation: null,
  year: null,
  engine: null,
  body: null,
};

/** Ответ нормализатора autoplus-ai (api.py), как его принимает NestJS. */
function intent(
  over: Partial<Omit<QwenIntentResult, 'vehicle'>> & {
    vehicle?: Partial<QwenIntentResult['vehicle']>;
  },
): QwenIntentResult {
  return {
    intent: 'check_stock',
    language: 'ru',
    part: { name: null, position: null },
    order: { number: null },
    ...over,
    vehicle: { brand: null, ...blank, ...over.vehicle },
  } as QwenIntentResult;
}

const item = (id: number, name: string, quantity = 1, price = 1000) => ({
  id,
  organizationId: 'org',
  name,
  description: null,
  quantity,
  price,
});

describe('диалог: от JSON парсера до ответа клиенту', () => {
  const repo = { find: jest.fn() };
  let service: StockService;

  beforeEach(async () => {
    repo.find.mockReset();
    const moduleRef = await Test.createTestingModule({
      providers: [
        StockService,
        { provide: getRepositoryToken(Item), useValue: repo },
      ],
    }).compile();
    service = moduleRef.get(StockService);
  });

  const reply = (i: QwenIntentResult) => service.buildCheckStockReply('org', i);

  it('T1: «рулевая рейка барма бмв?» — есть рейка E60, поколение уточняется', async () => {
    repo.find.mockResolvedValue([item(1, 'Рейка рулевая BMW E60', 2, 90000)]);
    const text = await reply(
      intent({
        language: 'kk',
        vehicle: { brand: 'BMW' },
        part: { name: 'steering_rack', position: null },
      }),
    );
    expect(text).toContain('Иә, бар');
    expect(text).toContain('Рейка рулевая BMW E60 — 90 000 ₸');
    expect(text).toContain('E60 ме?');
  });

  it('T2: «бмв е60 рулевая рейка есть?» — поколение известно, вопроса нет', async () => {
    repo.find.mockResolvedValue([
      item(1, 'рулевая рейка BMW E60'),
      item(2, 'рулевая рейка BMW E46'),
    ]);
    const text = await reply(
      intent({
        vehicle: { brand: 'BMW', model: '5 Series', generation: 'E60' },
        part: { name: 'steering_rack', position: null },
      }),
    );
    expect(text).toContain('Да, есть: рулевая рейка на BMW 5 Series E60');
    expect(text).not.toContain('E46');
    expect(text).not.toContain('У вас');
  });

  it('T3: «камри 70 передние колодки есть?» — только передние', async () => {
    repo.find.mockResolvedValue([
      item(1, 'Камри XV70 колодки задние'),
      item(2, 'Toyota Camry XV70 колодки передние Brembo', 3, 15000),
    ]);
    const text = await reply(
      intent({
        vehicle: { brand: 'Toyota', model: 'Camry', generation: 'XV70' },
        part: { name: 'brake_pad', position: 'front' },
      }),
    );
    expect(text).toContain('Brembo');
    expect(text).not.toContain('задние');
  });

  it('T4: мерс W211 автомат, цена — ответ на казахском с ценой', async () => {
    repo.find.mockResolvedValue([item(1, 'АКПП Mercedes W211', 1, 250000)]);
    const text = await reply(
      intent({
        intent: 'check_price',
        language: 'kk',
        vehicle: { brand: 'Mercedes', generation: 'W211' },
        part: { name: 'automatic_transmission', position: null },
      }),
    );
    expect(text).toContain('Бағасын айтамыз');
    expect(text).toContain('250 000 ₸');
  });

  it('T5: «рулевая рейка на BMW E60 сколько стоит?» — check_price с ценой', async () => {
    repo.find.mockResolvedValue([item(1, 'Рулевая рейка BMW E60', 1, 85000)]);
    const text = await reply(
      intent({
        intent: 'check_price',
        vehicle: { brand: 'BMW', generation: 'E60' },
        part: { name: 'steering_rack', position: null },
      }),
    );
    expect(text).toContain('Рулевая рейка BMW E60 — 85 000 ₸');
    expect(text.startsWith('Подскажу по цене')).toBe(true);
  });

  it('T6: «есть ли на BMW?» — деталь не названа, каталог не опрашивается', async () => {
    const text = await reply(intent({ vehicle: { brand: 'BMW' } }));
    expect(repo.find).not.toHaveBeenCalled();
    expect(text).toContain('Какая деталь');
    expect(text).not.toContain('нашли');
  });

  it('T7: «рулевая рейка» без марки — ищем деталь, марку не выдумываем', async () => {
    repo.find.mockResolvedValue([item(1, 'Рулевая рейка BMW E60')]);
    const text = await reply(
      intent({
        intent: 'search_part',
        part: { name: 'steering_rack', position: null },
      }),
    );
    expect(text).toContain('Рулевая рейка BMW E60');
    expect(text).toContain('E60');
  });

  it('не раскрывает остаток и не говорит «комплектов»', async () => {
    repo.find.mockResolvedValue([item(1, 'Рулевая рейка BMW E60', 7, 85000)]);
    const text = await reply(
      intent({
        vehicle: { brand: 'BMW', generation: 'E60' },
        part: { name: 'steering_rack', position: null },
      }),
    );
    expect(text).not.toMatch(/в наличии|комплект|шт|дана|Қолда бар|7/i);
    expect(text).toContain('Если подходит, напишите — оформим.');
  });

  it('товара нет: не утверждаем, что его не бывает, просим данные', async () => {
    repo.find.mockResolvedValue([item(1, 'Фара BMW E60')]);
    const text = await reply(
      intent({
        vehicle: { brand: 'BMW' },
        part: { name: 'steering_rack', position: null },
      }),
    );
    expect(text).toContain('в наличии сейчас не нашли');
    expect(text).toContain('менеджер проверит вручную');
  });
});

describe('поиск по каталогу', () => {
  const rack = { name: 'steering_rack', position: null };

  it('порядок слов в названии не важен', () => {
    expect(
      itemMatchesStockIntent(
        'Рейка рулевая BMW E60', null, 1,
        { brand: 'BMW', ...blank }, rack, true,
      ),
    ).toBe(true);
  });

  it('БМВ = BMW, кириллическая «е60» = E60', () => {
    expect(
      itemMatchesStockIntent(
        'БМВ е60 рулевая рейка', null, 1,
        { brand: 'BMW', ...blank, generation: 'E60' }, rack, true,
      ),
    ).toBe(true);
    expect(
      itemMatchesStockIntent(
        'BMW E60 рулевая рейка', null, 1,
        { brand: 'бмв', ...blank, generation: 'е60' }, rack, true,
      ),
    ).toBe(true);
  });

  it('другая марка и другое поколение не подходят', () => {
    const bmwE60 = { brand: 'BMW', ...blank, generation: 'E60' };
    expect(itemMatchesStockIntent('Mercedes E60 рулевая рейка', null, 1, bmwE60, rack, true)).toBe(false);
    expect(itemMatchesStockIntent('BMW E39 рулевая рейка', null, 1, bmwE60, rack, true)).toBe(false);
  });

  it('без названия детали ничего не подбирается', () => {
    expect(
      itemMatchesStockIntent(
        'Фара BMW E60', null, 1,
        { brand: 'BMW', ...blank }, { name: null, position: null }, true,
      ),
    ).toBe(false);
  });

  it('тормозные колодки не считаются тормозными дисками', () => {
    expect(
      itemMatchesStockIntent(
        'Тормозные колодки Brembo', null, 1,
        { brand: null, ...blank }, { name: 'brake_disc', position: null }, true,
      ),
    ).toBe(false);
  });

  it('foldText идемпотентна и не ломает обычные слова', () => {
    expect(foldText('БМВ Е60, мерс М113!')).toBe('bmw e60 mercedes m113');
    expect(foldText(foldText('БМВ Е60'))).toBe(foldText('БМВ Е60'));
    expect(foldText('Резина')).toBe('резина');
  });
});

describe('контракт с autoplus-ai', () => {
  it('installation_warranty и engine_origin не превращаются в unknown', () => {
    for (const name of ['installation_warranty', 'engine_origin']) {
      const parsed = parseQwenIntentResponse({
        intent: name,
        language: 'ru',
        vehicle: blank,
        part: { name: 'engine', position: null },
        order: { number: null },
      });
      expect(parsed?.intent).toBe(name);
    }
  });
});
