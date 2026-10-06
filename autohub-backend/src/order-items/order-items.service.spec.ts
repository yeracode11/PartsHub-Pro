import { BadRequestException, NotFoundException } from '@nestjs/common';
import { MoreThanOrEqual } from 'typeorm';
import { OrderItemsService, normalizeOrderItems } from './order-items.service';
import { Item } from '../items/entities/item.entity';

describe('OrderItemsService.createOrderItems', () => {
  const stock = {
    id: 7,
    organizationId: 'org-a',
    name: 'Фара',
    price: 1000,
    quantity: 2,
  };

  function setup(updateAffected: number) {
    const execute = jest.fn().mockResolvedValue({ affected: updateAffected });
    const where = jest.fn().mockReturnValue({
      setParameter: jest.fn().mockReturnValue({ execute }),
    });
    const itemRepo = {
      findOne: jest.fn(async ({ where: w }) =>
        w.id === stock.id && w.organizationId === stock.organizationId
          ? stock
          : null,
      ),
      createQueryBuilder: jest.fn(() => ({
        update: () => ({ set: () => ({ where }) }),
      })),
    };
    const orderItemRepo = {
      create: jest.fn((v) => v),
      save: jest.fn(async (v) => ({ id: 1, ...v })),
    };
    const manager = {
      getRepository: (entity: unknown) =>
        entity === Item ? itemRepo : orderItemRepo,
    };
    const service = new OrderItemsService(
      orderItemRepo as never,
      { manager } as never,
    );
    return { service, itemRepo, orderItemRepo, where };
  }

  it('does not find an item of another organization', async () => {
    const { service, orderItemRepo } = setup(1);
    await expect(
      service.createOrderItems(1, 'org-b', [{ itemId: 7, quantity: 1 }]),
    ).rejects.toThrow(NotFoundException);
    expect(orderItemRepo.save).not.toHaveBeenCalled();
  });

  it('decrements only when enough stock in the same organization', async () => {
    const { service, where } = setup(1);
    await service.createOrderItems(1, 'org-a', [{ itemId: 7, quantity: 2 }]);
    expect(where).toHaveBeenCalledWith({
      id: 7,
      organizationId: 'org-a',
      quantity: MoreThanOrEqual(2),
    });
  });

  it('rejects selling more than available', async () => {
    const { service, orderItemRepo } = setup(0);
    await expect(
      service.createOrderItems(1, 'org-a', [{ itemId: 7, quantity: 3 }]),
    ).rejects.toThrow(BadRequestException);
    expect(orderItemRepo.save).not.toHaveBeenCalled();
  });

  it('skips decrement for B2C requests but still checks organization', async () => {
    const { service, itemRepo, orderItemRepo } = setup(0);
    await service.createOrderItems(1, 'org-a', [{ itemId: 7, quantity: 5 }], {
      skipQuantityCheck: true,
    });
    expect(itemRepo.createQueryBuilder).not.toHaveBeenCalled();
    expect(orderItemRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({ itemId: 7, quantity: 5, subtotal: 5000 }),
    );
  });
});

describe('normalizeOrderItems', () => {
  it('merges duplicate items', () => {
    expect(
      normalizeOrderItems([
        { itemId: 1, quantity: 1 },
        { itemId: 1, quantity: 2 },
      ]),
    ).toEqual([{ itemId: 1, quantity: 3 }]);
  });

  it.each([
    [[{ itemId: 1, quantity: 0 }]],
    [[{ itemId: 1, quantity: -1 }]],
    [[{ itemId: 1, quantity: 1.5 }]],
    [[{ itemId: 'x', quantity: 1 }]],
    ['not-an-array'],
  ])('rejects invalid input %j', (input) => {
    expect(() => normalizeOrderItems(input)).toThrow(BadRequestException);
  });
});
