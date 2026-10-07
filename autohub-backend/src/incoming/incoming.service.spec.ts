import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { averagePurchaseCost, IncomingService } from './incoming.service';
import { InventoryService } from '../inventory/inventory.service';
import { MovementType } from '../inventory/entities/inventory-movement.entity';
import {
  IncomingDoc,
  IncomingDocType,
  IncomingDocStatus,
} from './entities/incoming-doc.entity';
import { IncomingItem } from './entities/incoming-item.entity';
import { Item } from '../items/entities/item.entity';

describe('IncomingService', () => {
  let service: IncomingService;
  let incomingDocRepository: any;
  let incomingItemRepository: any;
  let itemRepository: any;
  let dataSource: any;
  let queryRunner: any;
  let inventory: { apply: jest.Mock };

  const currentYear = new Date().getFullYear();

  beforeEach(async () => {
    queryRunner = {
      connect: jest.fn().mockResolvedValue(undefined),
      startTransaction: jest.fn().mockResolvedValue(undefined),
      commitTransaction: jest.fn().mockResolvedValue(undefined),
      rollbackTransaction: jest.fn().mockResolvedValue(undefined),
      release: jest.fn().mockResolvedValue(undefined),
      query: jest.fn().mockResolvedValue([{ id: 'new-doc-id' }]),
    };

    dataSource = {
      createQueryRunner: jest.fn().mockReturnValue(queryRunner),
    };

    incomingDocRepository = {
      createQueryBuilder: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        getRawMany: jest
          .fn()
          .mockResolvedValue([
            { docNumber: `ПН-${currentYear}-000005` },
            { docNumber: `ПН-${currentYear}-000010` },
          ]),
      }),
      findOne: jest.fn().mockImplementation(({ where }) => {
        if (where?.id === 'new-doc-id') {
          return Promise.resolve({
            id: 'new-doc-id',
            docNumber: `ПН-${currentYear}-000011`,
            status: IncomingDocStatus.DRAFT,
          });
        }
        return Promise.resolve(null);
      }),
    };

    incomingItemRepository = {};
    itemRepository = {};
    inventory = { apply: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        IncomingService,
        {
          provide: getRepositoryToken(IncomingDoc),
          useValue: incomingDocRepository,
        },
        {
          provide: getRepositoryToken(IncomingItem),
          useValue: incomingItemRepository,
        },
        {
          provide: getRepositoryToken(Item),
          useValue: itemRepository,
        },
        {
          provide: DataSource,
          useValue: dataSource,
        },
        {
          provide: InventoryService,
          useValue: inventory,
        },
      ],
    }).compile();

    service = moduleRef.get<IncomingService>(IncomingService);
  });

  it('generates the next sequential docNumber based on existing numbers', async () => {
    const doc = await service.create('org-1', 'user-1', {
      type: IncomingDocType.USED_PARTS,
      date: new Date().toISOString(),
    });

    expect(doc).toBeDefined();
    expect(queryRunner.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO "incoming_docs"'),
      expect.arrayContaining(['org-1', `ПН-${currentYear}-000011`]),
    );
  });

  it('retries with next candidate number if unique conflict 23505 occurs', async () => {
    let callCount = 0;
    queryRunner.query = jest.fn().mockImplementation(() => {
      callCount++;
      if (callCount === 1) {
        const err: any = new Error(
          'duplicate key value violates unique constraint',
        );
        err.code = '23505';
        return Promise.reject(err);
      }
      return Promise.resolve([{ id: 'new-doc-id' }]);
    });

    const doc = await service.create('org-1', 'user-1', {
      type: IncomingDocType.USED_PARTS,
      date: new Date().toISOString(),
    });

    expect(doc).toBeDefined();
    expect(callCount).toBe(2);
    expect(queryRunner.rollbackTransaction).toHaveBeenCalledTimes(1);
    expect(queryRunner.commitTransaction).toHaveBeenCalledTimes(1);
  });
  describe('проведение', () => {
    let manager: any;
    let lockedItem: any;
    let claimResult: { affected: number };

    const draftDoc = (items: any[]) => ({
      id: 'doc-1',
      organizationId: 'org-1',
      status: IncomingDocStatus.DRAFT,
      items,
    });

    const line = (overrides: any = {}) => ({
      name: 'Фара',
      quantity: 2,
      purchasePrice: '30000.00',
      salePrice: null,
      warehouseCell: 'A-1',
      oem: null,
      barcode: null,
      ...overrides,
    });

    beforeEach(() => {
      claimResult = { affected: 1 };
      lockedItem = {
        id: 5,
        quantity: 2,
        price: '60000.00',
        purchaseCost: '20000.00',
        barcode: null,
        oem: null,
      };
      const claimQb: any = {};
      for (const m of ['update', 'set', 'where', 'andWhere']) {
        claimQb[m] = jest.fn(() => claimQb);
      }
      claimQb.execute = jest.fn(async () => claimResult);
      const itemQb: any = {};
      for (const m of ['addSelect', 'where', 'andWhere', 'setLock']) {
        itemQb[m] = jest.fn(() => itemQb);
      }
      itemQb.getOne = jest.fn(async () => lockedItem);
      manager = {
        createQueryBuilder: jest.fn((entity?: unknown) =>
          entity ? itemQb : claimQb,
        ),
        update: jest.fn(),
        save: jest.fn(async (_entity, data) => ({ ...data, id: 9 })),
      };
      dataSource.transaction = jest.fn(async (cb) => cb(manager));
    });

    it('пишет среднюю закупочную цену и не поднимает цену продажи', async () => {
      jest
        .spyOn(service, 'findOne')
        .mockResolvedValue(draftDoc([line({ itemId: 5 })]) as any);

      await service.processDocument('doc-1', 'org-1');

      expect(manager.update).toHaveBeenCalledWith(
        Item,
        { id: 5, organizationId: 'org-1' },
        { purchaseCost: '25000.00', warehouseCell: 'A-1' },
      );
      expect(inventory.apply).toHaveBeenCalledWith(
        expect.objectContaining({
          organizationId: 'org-1',
          itemId: 5,
          type: MovementType.RECEIVING,
          quantityDelta: 2,
          documentType: 'incoming_doc',
        }),
        manager,
      );
    });

    it('новая деталь получает цену продажи из накладной и закупочную отдельно', async () => {
      jest
        .spyOn(service, 'findOne')
        .mockResolvedValue(
          draftDoc([
            line({ salePrice: '45000.00', oem: '81150-33A10' }),
          ]) as any,
        );

      await service.processDocument('doc-1', 'org-1');

      expect(manager.save).toHaveBeenCalledWith(
        Item,
        expect.objectContaining({
          organizationId: 'org-1',
          price: 45000,
          purchaseCost: '30000.00',
          oemNormalized: '8115033A10',
          quantity: 0,
        }),
      );
      expect(inventory.apply).toHaveBeenCalledWith(
        expect.objectContaining({
          itemId: 9,
          type: MovementType.RECEIVING,
          quantityDelta: 2,
        }),
        manager,
      );
    });

    it('второе параллельное проведение не добавляет остаток повторно', async () => {
      jest
        .spyOn(service, 'findOne')
        .mockResolvedValue(draftDoc([line({ itemId: 5 })]) as any);
      claimResult = { affected: 0 };

      await expect(service.processDocument('doc-1', 'org-1')).rejects.toThrow(
        'Накладная уже проведена',
      );
      expect(manager.update).not.toHaveBeenCalled();
      expect(inventory.apply).not.toHaveBeenCalled();
    });
  });
});

describe('averagePurchaseCost', () => {
  it('усредняет старый остаток и новую партию', () => {
    expect(
      averagePurchaseCost(
        { quantity: 3, cost: 100 },
        { quantity: 1, cost: 200 },
      ),
    ).toBe('125.00');
  });

  it('без старой цены или остатка берёт цену партии', () => {
    expect(
      averagePurchaseCost(
        { quantity: 3, cost: null },
        { quantity: 1, cost: 200 },
      ),
    ).toBe('200.00');
    expect(
      averagePurchaseCost(
        { quantity: -1, cost: 50 },
        { quantity: 2, cost: 80 },
      ),
    ).toBe('80.00');
  });
});
