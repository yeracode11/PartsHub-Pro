import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ListingsService } from './listings.service';
import { Listing } from './entities/listing.entity';
import { Item } from '../items/entities/item.entity';
import { ListingChannel, ListingStatus } from './marketplace-adapter';

describe('ListingsService', () => {
  const item = {
    id: 6,
    organizationId: 'org-a',
    name: 'Фара',
    description: null,
    images: [],
    price: '10000.00',
    quantity: 4,
    reservedQuantity: 1,
  };

  let service: ListingsService;
  let listings: {
    find: jest.Mock;
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let items: { findOne: jest.Mock; update: jest.Mock };

  let stored: Record<string, unknown> | null;

  beforeEach(async () => {
    stored = null;
    listings = {
      find: jest.fn(),
      findOne: jest.fn(async () => null),
      create: jest.fn((data) => data),
      save: jest.fn(async (data) => {
        stored = { ...data, id: 'list-1' };
        listings.findOne.mockResolvedValue(stored);
        return stored;
      }),
    };
    items = {
      findOne: jest.fn(async ({ where }) =>
        where.id === item.id && where.organizationId === item.organizationId
          ? { ...item }
          : null,
      ),
      update: jest.fn(),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        ListingsService,
        { provide: getRepositoryToken(Listing), useValue: listings },
        { provide: getRepositoryToken(Item), useValue: items },
      ],
    }).compile();
    service = moduleRef.get(ListingsService);
  });

  it('не видит товар другой организации', async () => {
    await expect(
      service.create('org-b', { itemId: 6, channel: 'catalog' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('каталог публикует локально и включает витрину', async () => {
    listings.findOne.mockResolvedValue(null);
    const saved = await service.create('org-a', {
      itemId: 6,
      channel: ListingChannel.CATALOG,
    });
    expect(saved).toMatchObject({
      status: ListingStatus.PUBLISHED,
      externalId: 'catalog:6',
      quantity: 3,
    });
    expect(items.update).toHaveBeenCalledWith(
      { id: 6, organizationId: 'org-a' },
      { syncedToB2C: true },
    );
  });

  it('Kolesa не уходит в сеть и остаётся в очереди', async () => {
    listings.findOne.mockResolvedValue(null);
    const saved = await service.create('org-a', {
      itemId: 6,
      channel: ListingChannel.KOLESA,
      publish: true,
    });
    expect(saved).toMatchObject({
      status: ListingStatus.NEEDS_SYNC,
      lastSyncError: 'Канал не подключён',
    });
    expect(items.update).not.toHaveBeenCalled();
  });

  it('повтор канала в своей организации запрещён', async () => {
    listings.findOne.mockResolvedValue({ id: 'list-1', status: ListingStatus.PUBLISHED });
    await expect(
      service.create('org-a', { itemId: 6, channel: 'catalog' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});
