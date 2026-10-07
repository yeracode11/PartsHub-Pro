import { BadRequestException, NotFoundException } from '@nestjs/common';
import { OrderItemsService, normalizeOrderItems } from './order-items.service';
import { Item } from '../items/entities/item.entity';
import { MovementType } from '../inventory/entities/inventory-movement.entity';

describe('OrderItemsService.createOrderItems', () => {
  const stock = {
    id: 7,
    organizationId: 'org-a',
    name: 'Фара',
    price: 1000,
    quantity: 2,
  };

  function setup(enough: boolean) {
    const inventory = {
      apply: jest.fn(async () => {
        if (!enough) {
          throw new BadRequestException(
            'Недостаточно на складе: «Фара», доступно 2',
          );
        }
      }),
    };
    const itemRepo = {
      findOne: jest.fn(async ({ where: w }) =>
        w.id === stock.id && w.organizationId === stock.organizationId
          ? stock
          : null,
      ),
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
      inventory as never,
    );
    return { service, itemRepo, orderItemRepo, inventory };
  }

  it('does not find an item of another organization', async () => {
    const { service, orderItemRepo, inventory } = setup(true);
    await expect(
      service.createOrderItems(1, 'org-b', [{ itemId: 7, quantity: 1 }]),
    ).rejects.toThrow(NotFoundException);
    expect(orderItemRepo.save).not.toHaveBeenCalled();
    expect(inventory.apply).not.toHaveBeenCalled();
  });

  it('decrements only when enough stock in the same organization', async () => {
    const { service, inventory } = setup(true);
    await service.createOrderItems(1, 'org-a', [{ itemId: 7, quantity: 2 }]);
    expect(inventory.apply).toHaveBeenCalledWith(
      expect.objectContaining({
        organizationId: 'org-a',
        itemId: 7,
        type: MovementType.SALE,
        quantityDelta: -2,
        documentType: 'order',
        documentId: '1',
      }),
      expect.anything(),
    );
  });

  it('rejects selling more than available', async () => {
    const { service, orderItemRepo } = setup(false);
    await expect(
      service.createOrderItems(1, 'org-a', [{ itemId: 7, quantity: 3 }]),
    ).rejects.toThrow(BadRequestException);
    expect(orderItemRepo.save).not.toHaveBeenCalled();
  });

  it('skips decrement for B2C requests but still checks organization', async () => {
    const { service, inventory, orderItemRepo } = setup(false);
    await service.createOrderItems(1, 'org-a', [{ itemId: 7, quantity: 5 }], {
      skipQuantityCheck: true,
    });
    expect(inventory.apply).not.toHaveBeenCalled();
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
