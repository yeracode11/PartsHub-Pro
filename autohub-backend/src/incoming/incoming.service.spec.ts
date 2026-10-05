import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { IncomingService } from './incoming.service';
import { IncomingDoc, IncomingDocType, IncomingDocStatus } from './entities/incoming-doc.entity';
import { IncomingItem } from './entities/incoming-item.entity';
import { Item } from '../items/entities/item.entity';

describe('IncomingService', () => {
  let service: IncomingService;
  let incomingDocRepository: any;
  let incomingItemRepository: any;
  let itemRepository: any;
  let dataSource: any;
  let queryRunner: any;

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
        getRawMany: jest.fn().mockResolvedValue([
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
      expect.arrayContaining([
        'org-1',
        `ПН-${currentYear}-000011`,
      ]),
    );
  });

  it('retries with next candidate number if unique conflict 23505 occurs', async () => {
    let callCount = 0;
    queryRunner.query = jest.fn().mockImplementation(() => {
      callCount++;
      if (callCount === 1) {
        const err: any = new Error('duplicate key value violates unique constraint');
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
});
