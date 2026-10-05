import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { DonorsService } from './donors.service';
import { DonorStatus, DonorVehicle } from './entities/donor-vehicle.entity';
import { Item } from '../items/entities/item.entity';

const ORG = '11111111-1111-1111-1111-111111111111';

const makeQueryBuilder = (rows: any[]) => {
  const qb: any = {};
  for (const method of [
    'select',
    'addSelect',
    'from',
    'innerJoin',
    'where',
    'andWhere',
    'groupBy',
  ]) {
    qb[method] = jest.fn().mockReturnValue(qb);
  }
  qb.getRawMany = jest.fn().mockResolvedValue(rows);
  return qb;
};

describe('DonorsService', () => {
  let service: DonorsService;
  let donorRepo: any;
  let itemRepo: any;
  let dataSource: any;
  let manager: any;

  const donor = (overrides: Partial<DonorVehicle> = {}): DonorVehicle =>
    ({
      id: 7,
      organizationId: ORG,
      brand: 'Toyota',
      model: 'Camry',
      year: 2015,
      vin: 'JTNBF3EK0F3000001',
      engine: '2AR-FE',
      mileage: 180000,
      purchasePrice: '900000.00',
      extraCosts: '100000.00',
      scrapIncome: '0.00',
      status: DonorStatus.AWAITING,
      ...overrides,
    }) as any;

  beforeEach(async () => {
    donorRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn((d) => d),
      save: jest.fn(async (d) => ({ ...d, id: 7 })),
      update: jest.fn(),
      delete: jest.fn(),
    };
    itemRepo = {
      find: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      createQueryBuilder: jest.fn(() =>
        makeQueryBuilder([
          { donorId: 7, partsCount: '3', unitsInStock: '2', stockValue: '150000' },
        ]),
      ),
    };
    manager = {
      create: jest.fn((_entity, data) => data),
      save: jest.fn(async (_entity, data) => data),
      update: jest.fn(),
    };
    dataSource = {
      createQueryBuilder: jest.fn(() =>
        makeQueryBuilder([
          { donorId: 7, soldRevenue: '400000', unitsSold: '1', pendingRevenue: '50000' },
        ]),
      ),
      transaction: jest.fn(async (cb) => cb(manager)),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        DonorsService,
        { provide: getRepositoryToken(DonorVehicle), useValue: donorRepo },
        { provide: getRepositoryToken(Item), useValue: itemRepo },
        { provide: DataSource, useValue: dataSource },
      ],
    }).compile();

    service = moduleRef.get(DonorsService);
  });

  it('ищет донора только внутри своей организации', async () => {
    donorRepo.findOne.mockResolvedValue(null);

    await expect(service.findOne(7, ORG, true)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(donorRepo.findOne).toHaveBeenCalledWith({
      where: { id: 7, organizationId: ORG },
    });
  });

  it('список содержит экономику по каждому донору', async () => {
    donorRepo.find.mockResolvedValue([donor()]);

    const [result] = await service.findAll(ORG, { includeFinance: true });

    expect(result.economics).toMatchObject({
      totalCost: 1_000_000,
      soldRevenue: 400_000,
      pendingRevenue: 50_000,
      stockValue: 150_000,
      paybackPercent: 40,
      forecastProfit: -400_000,
    });
  });

  it('кладовщик не видит закупочную цену и прибыль', async () => {
    donorRepo.find.mockResolvedValue([donor()]);

    const [result] = await service.findAll(ORG, { includeFinance: false });

    expect(result).not.toHaveProperty('purchasePrice');
    expect(result).not.toHaveProperty('extraCosts');
    expect(result).not.toHaveProperty('economics');
    expect((result as any).stock).toEqual({
      partsCount: 3,
      unitsInStock: 2,
      unitsSold: 1,
    });
  });

  it('снятые детали становятся б/у товарами склада с привязкой к донору', async () => {
    donorRepo.findOne.mockResolvedValue(donor());

    const parts = await service.addParts(7, ORG, {
      parts: [{ name: ' Фара левая ', price: 45000 }],
    });

    expect(parts[0]).toMatchObject({
      organizationId: ORG,
      donorId: 7,
      name: 'Фара левая',
      quantity: 1,
      condition: 'used',
      syncedToB2C: true,
    });
    expect(parts[0].description).toContain('Toyota Camry 2015');
    expect(parts[0].description).toContain('JTNBF3EK0F3000001');
    expect(manager.update).toHaveBeenCalledWith(
      DonorVehicle,
      { id: 7, organizationId: ORG },
      { status: DonorStatus.DISMANTLING },
    );
  });

  it('не принимает детали по закрытому донору', async () => {
    donorRepo.findOne.mockResolvedValue(donor({ status: DonorStatus.CLOSED }));

    await expect(
      service.addParts(7, ORG, { parts: [{ name: 'Дверь', price: 1 }] }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('не удаляет донора, с которого уже сняты детали', async () => {
    donorRepo.findOne.mockResolvedValue(donor());
    itemRepo.count.mockResolvedValue(2);

    await expect(service.remove(7, ORG)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(donorRepo.delete).not.toHaveBeenCalled();
  });

  describe('себестоимость деталей', () => {
    beforeEach(() => {
      donorRepo.findOne.mockResolvedValue(
        donor({ purchasePrice: '150000.00' as any, extraCosts: '50000.00' as any }),
      );
      itemRepo.find.mockResolvedValue([
        { id: 1, name: 'Двигатель', price: '300000.00', quantity: 0 },
        { id: 2, name: 'Фара', price: '50000.00', quantity: 1 },
      ]);
      dataSource.createQueryBuilder
        .mockReturnValueOnce(
          makeQueryBuilder([
            { donorId: 7, soldRevenue: '280000', unitsSold: '1', pendingRevenue: '50000' },
          ]),
        )
        .mockReturnValueOnce(
          makeQueryBuilder([
            // Двигатель продан со скидкой, одна фара в резерве
            { itemId: 1, soldQuantity: '1', soldRevenue: '280000', pendingQuantity: '0' },
            { itemId: 2, soldQuantity: '0', soldRevenue: '0', pendingQuantity: '1' },
          ]),
        );
    });

    it('учитывает проданные и зарезервированные штуки и считает прибыль с продаж', async () => {
      const result: any = await service.findOne(7, ORG, true);
      const [engine, headlight] = result.parts;

      expect(engine.unitCost).toBe(150_000);
      expect(engine.realizedProfit).toBe(130_000);
      expect(headlight.unitCost).toBe(25_000);
      expect(headlight.realizedProfit).toBe(0);
    });

    it('не отдаёт себестоимость кладовщику', async () => {
      const result: any = await service.findOne(7, ORG, false);

      expect(result.parts[0]).not.toHaveProperty('unitCost');
      expect(result.parts[0]).not.toHaveProperty('realizedProfit');
      expect(result.parts[0].soldQuantity).toBe(1);
    });
  });

  it('ограничивает число фото донора', async () => {
    donorRepo.findOne.mockResolvedValue(
      donor({ photos: Array.from({ length: 19 }, (_, i) => `/uploads/items/${i}.jpg`) }),
    );

    await expect(
      service.addPhotos(7, ORG, ['/uploads/items/a.jpg', '/uploads/items/b.jpg'], true),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(donorRepo.update).not.toHaveBeenCalled();
  });

  it('удаляет только фото, принадлежащее донору', async () => {
    donorRepo.findOne.mockResolvedValue(donor({ photos: ['/uploads/items/a.jpg'] }));

    await expect(
      service.removePhoto(7, ORG, '/uploads/items/other.jpg', true),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(donorRepo.update).not.toHaveBeenCalled();
  });

  it('нормализует VIN при создании и всегда начинает со статуса «ждёт разбора»', async () => {
    donorRepo.findOne.mockResolvedValue(donor());

    await service.create(ORG, {
      brand: 'Toyota',
      model: 'Camry',
      vin: ' jtnbf3ek0f3000001 ',
      purchasePrice: 900000,
    });

    expect(donorRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        organizationId: ORG,
        vin: 'JTNBF3EK0F3000001',
        status: DonorStatus.AWAITING,
      }),
    );
  });
});
