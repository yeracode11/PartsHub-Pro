import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { DonorsService } from './donors.service';
import { DonorStatus, DonorVehicle } from './entities/donor-vehicle.entity';
import { Item } from '../items/entities/item.entity';
import { AuditService } from '../audit/audit.service';
import { InventoryService } from '../inventory/inventory.service';
import { PartCompatibility } from '../items/entities/part-compatibility.entity';

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
  let audit: { record: jest.Mock; history: jest.Mock };

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
      deliveryCost: '60000.00',
      dismantlingCost: '40000.00',
      otherCosts: '0.00',
      scrapIncome: '0.00',
      status: DonorStatus.PURCHASED,
      dismantlingStartDate: null,
      dismantlingEndDate: null,
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
          {
            donorId: 7,
            partsCount: '3',
            unitsInStock: '2',
            stockValue: '150000',
          },
        ]),
      ),
    };
    manager = {
      create: jest.fn((_entity, data) => data),
      save: jest.fn(async (_entity, data) =>
        Array.isArray(data)
          ? data.map((d, i) => ({ id: 100 + i, ...d }))
          : { id: 7, ...data },
      ),
      update: jest.fn(),
      insert: jest.fn(),
    };
    audit = {
      record: jest.fn(),
      history: jest.fn().mockResolvedValue([]),
    };
    dataSource = {
      createQueryBuilder: jest.fn(() =>
        makeQueryBuilder([
          {
            donorId: 7,
            soldRevenue: '400000',
            unitsSold: '1',
            pendingRevenue: '50000',
          },
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
        { provide: AuditService, useValue: audit },
        {
          provide: InventoryService,
          useValue: {
            apply: jest.fn(async (change: { quantityDelta: number }) => ({
              quantity: change.quantityDelta,
            })),
          },
        },
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
    expect(result).not.toHaveProperty('deliveryCost');
    expect(result).not.toHaveProperty('dismantlingCost');
    expect(result).not.toHaveProperty('otherCosts');
    expect(result).not.toHaveProperty('economics');
    expect((result as any).stock).toEqual({
      partsCount: 3,
      unitsReceived: 3,
      unitsInStock: 2,
      unitsSold: 1,
      unitsReserved: 0,
      unitsWrittenOff: 0,
    });
  });

  it('снятые детали становятся б/у товарами склада с привязкой к донору', async () => {
    donorRepo.findOne.mockResolvedValue(donor());

    const parts = await service.addParts(7, ORG, {
      parts: [{ name: ' Фара левая ', price: 45000, oem: '81150-33A10' }],
    });

    expect(parts[0]).toMatchObject({
      organizationId: ORG,
      donorId: 7,
      name: 'Фара левая',
      oem: '81150-33A10',
      oemNormalized: '8115033A10',
      quantity: 1,
      condition: 'used',
      syncedToB2C: true,
    });
    expect(parts[0].description).toContain('Toyota Camry 2015');
    expect(parts[0].description).toContain('JTNBF3EK0F3000001');
    expect(manager.insert).toHaveBeenCalledWith(PartCompatibility, [
      expect.objectContaining({
        organizationId: ORG,
        itemId: 100,
        make: 'Toyota',
        model: 'Camry',
        yearFrom: 2015,
        yearTo: 2015,
        engine: '2AR-FE',
      }),
    ]);
    expect(manager.update).toHaveBeenCalledWith(
      DonorVehicle,
      { id: 7, organizationId: ORG },
      {
        status: DonorStatus.DISMANTLING,
        dismantlingStartDate: expect.any(String),
        dismantlingEndDate: null,
      },
    );
  });

  it('не принимает детали по донору в архиве', async () => {
    donorRepo.findOne.mockResolvedValue(
      donor({ status: DonorStatus.ARCHIVED }),
    );

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
        donor({
          purchasePrice: '150000.00' as any,
          deliveryCost: '50000.00' as any,
          dismantlingCost: '0.00' as any,
        }),
      );
      itemRepo.find.mockResolvedValue([
        { id: 1, name: 'Двигатель', price: '300000.00', quantity: 0 },
        { id: 2, name: 'Фара', price: '50000.00', quantity: 1 },
      ]);
      dataSource.createQueryBuilder
        .mockReturnValueOnce(
          makeQueryBuilder([
            {
              donorId: 7,
              soldRevenue: '280000',
              unitsSold: '1',
              pendingRevenue: '50000',
            },
          ]),
        )
        .mockReturnValueOnce(
          makeQueryBuilder([
            // Двигатель продан со скидкой, одна фара в резерве
            {
              itemId: 1,
              soldQuantity: '1',
              soldRevenue: '280000',
              pendingQuantity: '0',
            },
            {
              itemId: 2,
              soldQuantity: '0',
              soldRevenue: '0',
              pendingQuantity: '1',
            },
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
      donor({
        photos: Array.from({ length: 19 }, (_, i) => `/uploads/items/${i}.jpg`),
      }),
    );

    await expect(
      service.addPhotos(
        7,
        ORG,
        ['/uploads/items/a.jpg', '/uploads/items/b.jpg'],
        true,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(donorRepo.update).not.toHaveBeenCalled();
  });

  it('удаляет только фото, принадлежащее донору', async () => {
    donorRepo.findOne.mockResolvedValue(
      donor({ photos: ['/uploads/items/a.jpg'] }),
    );

    await expect(
      service.removePhoto(7, ORG, '/uploads/items/other.jpg', true),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(donorRepo.update).not.toHaveBeenCalled();
  });

  it('нормализует VIN при создании и по умолчанию начинает со статуса «куплен»', async () => {
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
        status: DonorStatus.PURCHASED,
      }),
    );
  });

  it('создаёт донора сразу на площадке, но не сразу в разборе', async () => {
    donorRepo.findOne.mockResolvedValue(donor());
    await service.create(ORG, {
      brand: 'Toyota',
      model: 'Camry',
      purchasePrice: 1,
      status: 'waiting_for_dismantling',
    });
    expect(donorRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({ status: DonorStatus.WAITING_FOR_DISMANTLING }),
    );

    await expect(
      service.create(ORG, {
        brand: 'Toyota',
        model: 'Camry',
        purchasePrice: 1,
        status: 'fully_dismantled',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  describe('смена статуса', () => {
    it('проставляет дату начала разбора и пишет только в свою организацию', async () => {
      donorRepo.findOne.mockResolvedValue(donor());

      await service.update(7, ORG, { status: 'dismantling' });

      expect(manager.update).toHaveBeenCalledWith(
        DonorVehicle,
        { id: 7, organizationId: ORG },
        {
          status: DonorStatus.DISMANTLING,
          dismantlingStartDate: expect.any(String),
          dismantlingEndDate: null,
        },
      );
    });

    it('отклоняет недопустимый переход', async () => {
      donorRepo.findOne.mockResolvedValue(donor());

      await expect(
        service.update(7, ORG, { status: 'fully_dismantled' }),
      ).rejects.toThrow('Нельзя перевести из «Куплен» в «Разобран полностью»');
      expect(manager.update).not.toHaveBeenCalled();
    });

    it('принимает статусы старой версии приложения', async () => {
      donorRepo.findOne.mockResolvedValue(
        donor({
          status: DonorStatus.FULLY_DISMANTLED,
          dismantlingEndDate: '2026-01-10',
        }),
      );

      await service.update(7, ORG, { status: 'closed' });

      expect(manager.update).toHaveBeenCalledWith(
        DonorVehicle,
        { id: 7, organizationId: ORG },
        { status: DonorStatus.ARCHIVED },
      );
    });

    it('не даёт закончить разбор раньше начала', async () => {
      donorRepo.findOne.mockResolvedValue(
        donor({
          status: DonorStatus.DISMANTLING,
          dismantlingStartDate: '2026-03-01',
        }),
      );

      await expect(
        service.update(7, ORG, { dismantlingEndDate: '2026-02-01' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  it('не принимает организацию и статус в обход правил через поля карточки', async () => {
    donorRepo.findOne.mockResolvedValue(donor());

    await service.update(7, ORG, {
      brand: 'Lexus',
      organizationId: 'other-org',
      id: 99,
    } as any);

    expect(manager.update).toHaveBeenCalledWith(
      DonorVehicle,
      { id: 7, organizationId: ORG },
      { brand: 'Lexus' },
    );
  });

  it('сообщает клиенту, куда можно перевести донора', async () => {
    donorRepo.find.mockResolvedValue([donor()]);
    const [result] = await service.findAll(ORG, { includeFinance: false });
    expect(result.allowedStatuses).toEqual([
      DonorStatus.WAITING_FOR_DISMANTLING,
      DonorStatus.DISMANTLING,
      DonorStatus.ARCHIVED,
    ]);
  });

  it('связывает деталь с донором: детали донора ищутся по donorId и организации', async () => {
    donorRepo.findOne.mockResolvedValue(donor());
    await service.findOne(7, ORG, false);
    expect(itemRepo.find).toHaveBeenCalledWith(
      expect.objectContaining({ where: { organizationId: ORG, donorId: 7 } }),
    );
  });

  describe('аудит', () => {
    it('пишет в журнал только изменённые деньги и статус, в той же транзакции', async () => {
      donorRepo.findOne.mockResolvedValue(donor());

      await service.update(
        7,
        ORG,
        { purchasePrice: 950000, deliveryCost: 60000, brand: 'Lexus' },
        'user-1',
      );

      expect(audit.record).toHaveBeenCalledWith(
        {
          organizationId: ORG,
          userId: 'user-1',
          entityType: 'donor_vehicle',
          entityId: 7,
          action: 'update',
          changes: { purchasePrice: { from: 900000, to: 950000 } },
        },
        manager,
      );
    });

    it('фиксирует начальные вложения при создании', async () => {
      donorRepo.findOne.mockResolvedValue(donor());

      await service.create(
        ORG,
        { brand: 'Toyota', model: 'Camry', purchasePrice: 900000 },
        'user-1',
      );

      const [entry, usedManager] = audit.record.mock.calls[0];
      expect(usedManager).toBe(manager);
      expect(entry).toMatchObject({
        organizationId: ORG,
        action: 'create',
        changes: {
          purchasePrice: { from: null, to: 900000 },
          status: { from: null, to: DonorStatus.PURCHASED },
        },
      });
    });

    it('записывает автоматический переход в разбор при снятии деталей', async () => {
      donorRepo.findOne.mockResolvedValue(donor());

      await service.addParts(
        7,
        ORG,
        { parts: [{ name: 'Фара', price: 1 }] },
        'user-1',
      );

      expect(audit.record).toHaveBeenCalledWith(
        expect.objectContaining({
          changes: {
            status: {
              from: DonorStatus.PURCHASED,
              to: DonorStatus.DISMANTLING,
            },
          },
        }),
        manager,
      );
    });

    it('не отдаёт историю чужого донора', async () => {
      donorRepo.findOne.mockResolvedValue(null);

      await expect(service.getHistory(7, 'other-org')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(audit.history).not.toHaveBeenCalled();
    });

    it('читает историю только своей организации', async () => {
      donorRepo.findOne.mockResolvedValue(donor());
      await service.getHistory(7, ORG);
      expect(audit.history).toHaveBeenCalledWith(ORG, 'donor_vehicle', 7);
    });
  });

  describe('сводная экономика', () => {
    it('считает по всем донорам организации одним запросом без списка id', async () => {
      donorRepo.find.mockResolvedValue([donor(), donor({ id: 8 } as any)]);
      const salesQb = makeQueryBuilder([
        { donorId: 7, soldRevenue: '400000', unitsSold: '1' },
      ]);
      dataSource.createQueryBuilder.mockReturnValueOnce(salesQb);

      const summary = await service.getEconomicsSummary(ORG);

      expect(donorRepo.find).toHaveBeenCalledWith({
        where: { organizationId: ORG },
      });
      expect(salesQb.andWhere).toHaveBeenCalledWith(
        'o."organizationId" = :organizationId',
        { organizationId: ORG },
      );
      expect(salesQb.andWhere).toHaveBeenCalledWith(
        'i."donorId" IS NOT NULL',
        expect.anything(),
      );
      expect(summary).toMatchObject({
        donorsCount: 2,
        totalCost: 2_000_000,
        realizedRevenue: 400_000,
        realizedProfit: -1_600_000,
      });
    });

    it('с фильтром по статусу ограничивает выборку id этих доноров', async () => {
      donorRepo.find.mockResolvedValue([donor()]);
      const salesQb = makeQueryBuilder([]);
      dataSource.createQueryBuilder.mockReturnValueOnce(salesQb);

      await service.getEconomicsSummary(ORG, DonorStatus.DISMANTLING);

      expect(donorRepo.find).toHaveBeenCalledWith({
        where: { organizationId: ORG, status: DonorStatus.DISMANTLING },
      });
      expect(salesQb.andWhere).toHaveBeenCalledWith(
        'i."donorId" IN (:...ids)',
        {
          ids: [7],
        },
      );
    });

    it('экономика одного донора недоступна из чужой организации', async () => {
      donorRepo.findOne.mockResolvedValue(null);
      await expect(service.getEconomics(7, 'other-org')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });
});
