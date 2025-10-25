import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Order } from './entities/order.entity';
import { OrderItemsService } from '../order-items/order-items.service';

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    private readonly orderItemsService: OrderItemsService,
  ) {}

  async getRecentOrders(organizationId: string, limit: number) {
    const orders = await this.orderRepository.find({
      where: { organizationId },
      relations: ['customer'],
      order: { createdAt: 'DESC' },
      take: limit,
    });

    return { orders };
  }

  // CRUD методы для управления заказами
  async findAll(organizationId: string) {
    return await this.orderRepository.find({
      where: { organizationId },
      relations: ['customer'],
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: number, organizationId: string) {
    const order = await this.orderRepository.findOne({
      where: { id, organizationId },
      relations: ['customer'],
    });
    if (!order) {
      throw new Error(`Order with ID ${id} not found`);
    }
    return order;
  }

  async create(
    organizationId: string,
    data: Partial<Order> & { items?: Array<{ itemId: number; quantity: number }> },
  ) {
    // Генерируем номер заказа если не указан
    if (!data.orderNumber) {
      const year = new Date().getFullYear();
      
      // Находим максимальный номер заказа для этого года
      const lastOrder = await this.orderRepository
        .createQueryBuilder('order')
        .where('order.organizationId = :organizationId', { organizationId })
        .andWhere('order.orderNumber LIKE :pattern', { pattern: `ORD-${year}-%` })
        .orderBy('order.orderNumber', 'DESC')
        .getOne();
      
      let nextNumber = 1;
      if (lastOrder && lastOrder.orderNumber) {
        // Извлекаем номер из формата ORD-2025-001
        const match = lastOrder.orderNumber.match(/ORD-\d{4}-(\d+)/);
        if (match) {
          nextNumber = parseInt(match[1], 10) + 1;
        }
      }
      
      data.orderNumber = `ORD-${year}-${String(nextNumber).padStart(3, '0')}`;
    }

    // Создаем заказ
    const order = this.orderRepository.create({
      orderNumber: data.orderNumber,
      organizationId,
      customerId: data.customerId,
      status: data.status || 'pending',
      paymentStatus: data.paymentStatus || 'pending',
      notes: data.notes,
      totalAmount: 0, // Пока 0, посчитаем после добавления товаров
    });
    
    const savedOrder = await this.orderRepository.save(order);

    // Если есть товары - добавляем их
    if (data.items && data.items.length > 0) {
      await this.orderItemsService.createOrderItems(savedOrder.id, data.items);
      
      // Пересчитываем totalAmount
      const total = await this.orderItemsService.calculateOrderTotal(savedOrder.id);
      savedOrder.totalAmount = total;
      await this.orderRepository.save(savedOrder);
    }

    // Возвращаем заказ с items
    return await this.orderRepository.findOne({
      where: { id: savedOrder.id },
      relations: ['customer', 'items', 'items.item'],
    });
  }

  async update(
    id: number,
    organizationId: string,
    data: Partial<Order> & { items?: Array<{ itemId: number; quantity: number }> },
  ) {
    await this.findOne(id, organizationId); // Проверка существования

    // Извлекаем items из data, чтобы не пытаться обновить relation
    const { items, ...orderData } = data;

    // Обновляем основные поля заказа
    if (Object.keys(orderData).length > 0) {
      await this.orderRepository.update({ id, organizationId }, orderData);
    }

    // Если передали новые items, обновляем их
    if (items && items.length > 0) {
      // Удаляем старые items
      await this.orderItemsService.deleteOrderItems(id);

      // Добавляем новые
      await this.orderItemsService.createOrderItems(id, items);

      // Пересчитываем totalAmount
      const total = await this.orderItemsService.calculateOrderTotal(id);
      await this.orderRepository.update({ id, organizationId }, { totalAmount: total });
    }

    return await this.findOne(id, organizationId);
  }

  async remove(id: number, organizationId: string) {
    await this.findOne(id, organizationId); // Проверка существования
    await this.orderRepository.delete({ id, organizationId });
    return { success: true };
  }
}

