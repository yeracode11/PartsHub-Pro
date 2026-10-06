import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, MoreThanOrEqual, Repository } from 'typeorm';
import { OrderItem } from './entities/order-item.entity';
import { Item } from '../items/entities/item.entity';

export const MAX_ORDER_LINES = 200;
export const MAX_LINE_QUANTITY = 10000;

export type OrderItemInput = { itemId: number; quantity: number };

@Injectable()
export class OrderItemsService {
  constructor(
    @InjectRepository(OrderItem)
    private readonly orderItemRepository: Repository<OrderItem>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
  ) {}

  /**
   * Создать позиции заказа. Без skipQuantityCheck списывает остаток атомарно и не уходит в минус.
   */
  async createOrderItems(
    orderId: number,
    organizationId: string,
    items: OrderItemInput[],
    options?: { skipQuantityCheck?: boolean },
    manager?: EntityManager,
  ): Promise<OrderItem[]> {
    const lines = normalizeOrderItems(items);
    const em = manager ?? this.itemRepository.manager;
    const itemRepo = em.getRepository(Item);
    const orderItemRepo = em.getRepository(OrderItem);
    const orderItems: OrderItem[] = [];

    for (const line of lines) {
      const item = await itemRepo.findOne({
        where: { id: line.itemId, organizationId },
      });
      if (!item) {
        throw new NotFoundException(`Товар #${line.itemId} не найден`);
      }

      if (!options?.skipQuantityCheck) {
        const result = await itemRepo
          .createQueryBuilder()
          .update(Item)
          .set({ quantity: () => 'quantity - :qty' })
          .where({
            id: item.id,
            organizationId,
            quantity: MoreThanOrEqual(line.quantity),
          })
          .setParameter('qty', line.quantity)
          .execute();
        if (!result.affected) {
          throw new BadRequestException(
            `Недостаточно на складе: «${item.name}», доступно ${item.quantity}`,
          );
        }
      }

      const priceAtTime = Number(item.price);
      const orderItem = orderItemRepo.create({
        orderId,
        itemId: item.id,
        quantity: line.quantity,
        priceAtTime,
        subtotal: priceAtTime * line.quantity,
      });
      orderItems.push(await orderItemRepo.save(orderItem));
    }

    return orderItems;
  }

  async getOrderItems(
    orderId: number,
    manager?: EntityManager,
  ): Promise<OrderItem[]> {
    const repo = manager
      ? manager.getRepository(OrderItem)
      : this.orderItemRepository;
    return await repo.find({
      where: { orderId },
      relations: ['item'],
    });
  }

  /**
   * Удалить все позиции заказа и вернуть остаток на склад.
   */
  async deleteOrderItems(
    orderId: number,
    manager?: EntityManager,
  ): Promise<void> {
    const em = manager ?? this.orderItemRepository.manager;
    const orderItems = await this.getOrderItems(orderId, em);

    for (const orderItem of orderItems) {
      if (orderItem.item) {
        await em
          .getRepository(Item)
          .increment({ id: orderItem.item.id }, 'quantity', orderItem.quantity);
      }
    }

    await em.getRepository(OrderItem).delete({ orderId });
  }

  async calculateOrderTotal(orderId: number): Promise<number> {
    const orderItems = await this.getOrderItems(orderId);
    return orderItems.reduce((sum, item) => sum + Number(item.subtotal), 0);
  }
}

/** Проверяет состав заказа из внешнего запроса и объединяет повторяющиеся товары. */
export function normalizeOrderItems(items: unknown): OrderItemInput[] {
  if (!Array.isArray(items)) {
    throw new BadRequestException('Список товаров должен быть массивом');
  }
  if (items.length > MAX_ORDER_LINES) {
    throw new BadRequestException(
      `Не больше ${MAX_ORDER_LINES} позиций в заказе`,
    );
  }

  const merged = new Map<number, number>();
  for (const raw of items as Array<{
    itemId?: unknown;
    quantity?: unknown;
  } | null>) {
    const itemId = Number(raw?.itemId);
    const quantity = Number(raw?.quantity);
    if (!Number.isInteger(itemId) || itemId <= 0) {
      throw new BadRequestException('Некорректный товар в заказе');
    }
    if (
      !Number.isInteger(quantity) ||
      quantity <= 0 ||
      quantity > MAX_LINE_QUANTITY
    ) {
      throw new BadRequestException('Некорректное количество товара');
    }
    merged.set(itemId, (merged.get(itemId) ?? 0) + quantity);
  }

  return [...merged.entries()].map(([itemId, quantity]) => {
    if (quantity > MAX_LINE_QUANTITY) {
      throw new BadRequestException('Некорректное количество товара');
    }
    return { itemId, quantity };
  });
}
