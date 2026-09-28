import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { StockService } from './stock.service';
import { Item } from '../items/entities/item.entity';
import { QwenIntentResult } from '../ai/qwen-intent.types';
import { itemMatchesStockIntent } from './part-search-keywords.util';

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
});
