import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OrderItem } from './entities/order-item.entity';
import { Item } from '../items/entities/item.entity';

@Injectable()
export class OrderItemsService {
  constructor(
    @InjectRepository(OrderItem)
    private readonly orderItemRepository: Repository<OrderItem>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
  ) {}

  /**
   * Создать items для заказа и автоматически списать со склада
   */
  async createOrderItems(
    orderId: number,
    items: Array<{ itemId: number; quantity: number }>,
    options?: { skipQuantityCheck?: boolean },
  ): Promise<OrderItem[]> {
    const orderItems: OrderItem[] = [];

    for (const itemData of items) {
      // Получаем товар из склада
      const item = await this.itemRepository.findOne({
        where: { id: itemData.itemId },
      });

      if (!item) {
        throw new Error(`Item with ID ${itemData.itemId} not found`);
      }

      // Проверяем наличие на складе (если не пропущено)
      if (!options?.skipQuantityCheck) {
        if (item.quantity < itemData.quantity) {
          // Для B2C создаем заказ даже если товара нет на складе
          console.log(`⚠️ Insufficient quantity for item "${item.name}". Available: ${item.quantity}, requested: ${itemData.quantity}`);
        }
        
        // Списываем со склада (если есть товар)
        if (item.quantity > 0) {
          item.quantity -= itemData.quantity;
          await this.itemRepository.save(item);
        }
      }

      // Создаем запись order_item
      const priceAtTime = Number(item.price);
      const subtotal = priceAtTime * itemData.quantity;

      const orderItem = this.orderItemRepository.create({
        orderId,
        itemId: item.id,
        quantity: itemData.quantity,
        priceAtTime,
        subtotal,
      });

      const savedOrderItem = await this.orderItemRepository.save(orderItem);
      orderItems.push(savedOrderItem);
    }

    return orderItems;
  }

  /**
   * Получить items заказа
   */
  async getOrderItems(orderId: number): Promise<OrderItem[]> {
    return await this.orderItemRepository.find({
      where: { orderId },
      relations: ['item'],
    });
  }

  /**
   * Удалить item из заказа и вернуть на склад
   */
  async removeOrderItem(orderItemId: number): Promise<void> {
    const orderItem = await this.orderItemRepository.findOne({
      where: { id: orderItemId },
      relations: ['item'],
    });

    if (!orderItem) {
      throw new Error(`OrderItem with ID ${orderItemId} not found`);
    }

    // Возвращаем на склад
    const item = orderItem.item;
    item.quantity += orderItem.quantity;
    await this.itemRepository.save(item);

    // Удаляем запись
    await this.orderItemRepository.delete(orderItemId);
  }

  /**
   * Удалить все items заказа и вернуть на склад
   */
  async deleteOrderItems(orderId: number): Promise<void> {
    const orderItems = await this.getOrderItems(orderId);

    for (const orderItem of orderItems) {
      // Возвращаем на склад
      const item = orderItem.item;
      if (item) {
        item.quantity += orderItem.quantity;
        await this.itemRepository.save(item);
      }
    }

    // Удаляем все записи order_items для этого заказа
    await this.orderItemRepository.delete({ orderId });
  }

  /**
   * Рассчитать общую сумму заказа
   */
  async calculateOrderTotal(orderId: number): Promise<number> {
    const orderItems = await this.getOrderItems(orderId);
    return orderItems.reduce((sum, item) => sum + Number(item.subtotal), 0);
  }
}

