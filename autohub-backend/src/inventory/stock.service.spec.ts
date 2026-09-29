import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { StockService } from './stock.service';
import { Item } from '../items/entities/item.entity';
import { QwenIntentResult } from '../ai/qwen-intent.types';
import {
  itemMatchesStockIntent,
  matchesEngineCode,
} from './part-search-keywords.util';

describe('StockService multi-tenant', () => {
  let service: StockService;
  const repo = { find: jest.fn() };

  const baseIntent: QwenIntentResult = {
    intent: 'check_stock',
    language: 'ru',
    vehicle: {
      brand: 'Toyota',
      model: 'Camry',
      generation: 'XV70',
      year: null,
      engine: null,
      body: null,
    },
    part: { name: 'brake_pad', position: 'front' },
    order: { number: null },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StockService,
        { provide: getRepositoryToken(Item), useValue: repo },
      ],
    }).compile();
    service = module.get(StockService);
  });

  it('TEST 1: returns item for org-A only', async () => {
    repo.find.mockResolvedValue([
      {
        id: 1,
        organizationId: 'org-A',
        name: 'Toyota Camry XV70 передние колодки Brembo',
        description: null,
        quantity: 2,
        price: 15000,
      },
      {
        id: 2,
        organizationId: 'org-A',
        name: 'Toyota Camry XV70 задние колодки',
        description: null,
        quantity: 5,
        price: 12000,
      },
    ]);

    const items = await service.findMatchingItems('org-A', baseIntent);

    expect(items).toHaveLength(1);
    expect(items[0].id).toBe(1);
  });

  it('TEST 2: org-A does not see org-B items', async () => {
    repo.find.mockResolvedValue([
      {
        id: 10,
        organizationId: 'org-B',
        name: 'Toyota Camry XV70 передние колодки',
        description: null,
        quantity: 3,
        price: 10000,
      },
    ]);

    const items = await service.findMatchingItems('org-A', baseIntent);

    expect(items).toHaveLength(0);
  });

  it('TEST 5: not found message when empty', async () => {
    repo.find.mockResolvedValue([]);

    const reply = await service.buildCheckStockReply('org-A', baseIntent);

    expect(reply).toContain('не найдены');
    expect(reply).toContain('Toyota Camry XV70');
  });

  it('BMW E60 steering_rack: finds product without "5 Series" in name', async () => {
    const intent: QwenIntentResult = {
      intent: 'check_stock',
      language: 'kk',
      vehicle: {
        brand: 'BMW',
        model: '5 Series',
        generation: 'E60',
        year: null,
        engine: null,
        body: null,
      },
      part: { name: 'steering_rack', position: null },
      order: { number: null },
    };

    repo.find.mockResolvedValue([
      {
        id: 42,
        organizationId: 'org-A',
        name: 'рулевая рейка BMW E60',
        description: null,
        quantity: 1,
        price: 85000,
      },
      {
        id: 43,
        organizationId: 'org-A',
        name: 'рулевая рейка BMW E46',
        description: null,
        quantity: 2,
        price: 70000,
      },
    ]);

    const items = await service.findMatchingItems('org-A', intent);

    expect(items).toHaveLength(1);
    expect(items[0].id).toBe(42);
  });

  it('engine M113: finds motor, not M112/M272', async () => {
    const intent: QwenIntentResult = {
      intent: 'check_stock',
      language: 'ru',
      vehicle: {
        brand: null,
        model: null,
        generation: null,
        year: null,
        engine: 'M113',
        body: null,
      },
      part: { name: 'engine', position: null },
      order: { number: null },
    };

    repo.find.mockResolvedValue([
      {
        id: 1,
        organizationId: 'org-A',
        name: 'двигатель M113',
        description: null,
        quantity: 1,
        price: 400000,
      },
      {
        id: 2,
        organizationId: 'org-A',
        name: 'мотор M112',
        description: null,
        quantity: 1,
        price: 350000,
      },
      {
        id: 3,
        organizationId: 'org-A',
        name: 'двигатель M272',
        description: null,
        quantity: 1,
        price: 380000,
      },
    ]);

    const items = await service.findMatchingItems('org-A', intent);

    expect(items).toHaveLength(1);
    expect(items[0].id).toBe(1);
  });
});

describe('itemMatchesStockIntent', () => {
  const vehicle = {
    brand: 'Toyota',
    model: 'Camry',
    generation: 'XV70',
    year: null,
    engine: null,
    body: null,
  };

  it('TEST 3: front does not match rear-only item', () => {
    expect(
      itemMatchesStockIntent(
        'Toyota Camry XV70 задние колодки',
        null,
        2,
        vehicle,
        { name: 'brake_pad', position: 'front' },
        true,
      ),
    ).toBe(false);

    expect(
      itemMatchesStockIntent(
        'Toyota Camry XV70 передние колодки',
        null,
        2,
        vehicle,
        { name: 'brake_pad', position: 'front' },
        true,
      ),
    ).toBe(true);
  });

  it('TEST 4: null position matches front and rear names', () => {
    expect(
      itemMatchesStockIntent(
        'Toyota Camry XV70 передние колодки',
        null,
        1,
        vehicle,
        { name: 'brake_pad', position: null },
        true,
      ),
    ).toBe(true);

    expect(
      itemMatchesStockIntent(
        'Toyota Camry XV70 задние колодки',
        null,
        1,
        vehicle,
        { name: 'brake_pad', position: null },
        true,
      ),
    ).toBe(true);
  });

  it('BMW E60 + steering_rack matches Cyrillic part name', () => {
    const bmw = {
      brand: 'BMW',
      model: '5 Series',
      generation: 'E60',
      year: null,
      engine: null,
      body: null,
    };

    expect(
      itemMatchesStockIntent(
        'рулевая рейка BMW E60',
        null,
        1,
        bmw,
        { name: 'steering_rack', position: null },
        true,
      ),
    ).toBe(true);

    expect(
      itemMatchesStockIntent(
        'рулевая рейка BMW E46',
        null,
        1,
        bmw,
        { name: 'steering_rack', position: null },
        true,
      ),
    ).toBe(false);
  });

  it('Camry XV70 still requires generation when model soft', () => {
    expect(
      itemMatchesStockIntent(
        'Toyota Camry передние колодки',
        null,
        1,
        vehicle,
        { name: 'brake_pad', position: 'front' },
        true,
      ),
    ).toBe(false);
  });
});

describe('matchesEngineCode', () => {
  it('M113 does not match M112 or M272', () => {
    expect(matchesEngineCode('двигатель m113 барма', 'M113')).toBe(true);
    expect(matchesEngineCode('двигатель m112', 'M113')).toBe(false);
    expect(matchesEngineCode('двигатель m272', 'M113')).toBe(false);
    expect(matchesEngineCode('om642 мотор', 'OM642')).toBe(true);
    expect(matchesEngineCode('n54 двигатель', 'N54')).toBe(true);
  });
});
