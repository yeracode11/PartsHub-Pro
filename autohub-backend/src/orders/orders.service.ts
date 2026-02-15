import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Order, OrderWorkStage } from './entities/order.entity';
import { OrderItemsService } from '../order-items/order-items.service';
import { CustomersService } from '../customers/customers.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { BusinessType } from '../common/enums/business-type.enum';

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    private readonly orderItemsService: OrderItemsService,
    private readonly customersService: CustomersService,
    private readonly whatsAppService: WhatsAppService,
    private readonly organizationsService: OrganizationsService,
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

  // Получить только заказы из B2C магазина
  async findB2COrders(organizationId: string) {
    return await this.orderRepository.find({
      where: { organizationId, isB2C: true },
      relations: ['customer', 'items', 'items.item'],
      order: { createdAt: 'DESC' },
    });
  }

  // CRUD методы для управления заказами
  async findAll(organizationId: string) {
    console.log('📦 OrdersService.findAll called');
    console.log('   organizationId:', organizationId);
    console.log('   organizationId type:', typeof organizationId);
    
    // Проверяем, есть ли вообще заказы в базе
    const allOrders = await this.orderRepository.find({
        relations: ['customer', 'items', 'items.item'],
      take: 10,
      });
    console.log(`   Total orders in DB: ${allOrders.length}`);
    if (allOrders.length > 0) {
      console.log('   Sample order organizationIds:', allOrders.map(o => o.organizationId));
    }
    
    const orders = await this.orderRepository.find({
      where: { organizationId },
      relations: ['customer', 'items', 'items.item'],
      order: { createdAt: 'DESC' },
    });
    console.log(`   ✅ Found ${orders.length} orders for organization ${organizationId}`);
    
    if (orders.length > 0) {
      console.log('   Order IDs:', orders.map(o => o.id));
      console.log('   Order numbers:', orders.map(o => o.orderNumber));
      console.log('   IsB2C flags:', orders.map(o => o.isB2C));
    }
    
    return orders;
  }

  async findOne(id: number, organizationId: string) {
    const order = await this.orderRepository.findOne({
      where: { id, organizationId },
      relations: ['customer', 'items', 'items.item'], // Загружаем товары с полной информацией
    });
    if (!order) {
      throw new Error(`Order with ID ${id} not found`);
    }
    return order;
  }

  async create(
    organizationId: string,
    data: Partial<Order> & {
      items?: Array<{ itemId: number; quantity: number }>;
      workStages?: OrderWorkStage[];
    },
    options?: { skipQuantityCheck?: boolean },
  ) {
    console.log('📦 OrdersService.create called');
    console.log('   organizationId:', organizationId);
    console.log('   isB2C:', (data as any).isB2C);
    console.log('   items count:', data.items?.length || 0);
    
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
    const isB2C = (data as any).isB2C || false;
    const isServiceOrg = await this.isServiceOrganization(organizationId);
    const order = this.orderRepository.create({
      orderNumber: data.orderNumber,
      organizationId,
      customerId: data.customerId,
      status: data.status || 'pending',
      paymentStatus: data.paymentStatus || 'pending',
      notes: data.notes,
      shippingAddress: (data as any).shippingAddress || null, // Адрес доставки для B2C
      isB2C,
      totalAmount: 0, // Пока 0, посчитаем после добавления товаров
      workStages: isServiceOrg
        ? data.workStages && data.workStages.length > 0
          ? this.normalizeWorkStages(data.workStages)
          : isB2C
            ? this.getDefaultWorkStages()
            : null
        : null,
    });
    
    console.log('   Creating order with data:', JSON.stringify({
      orderNumber: order.orderNumber,
      organizationId: order.organizationId,
      organizationIdType: typeof order.organizationId,
      isB2C: order.isB2C,
      status: order.status,
    }, null, 2));
    
    const savedOrder = await this.orderRepository.save(order);
    console.log(`   ✅ Order saved with ID: ${savedOrder.id}`);
    console.log(`   ✅ Saved order organizationId: ${savedOrder.organizationId} (type: ${typeof savedOrder.organizationId})`);
    
    // Проверяем, что заказ действительно сохранился с правильным organizationId
    const verifyOrder = await this.orderRepository.findOne({
      where: { id: savedOrder.id },
    });
    if (verifyOrder) {
      console.log(`   ✅ Verified order organizationId: ${verifyOrder.organizationId}`);
      if (verifyOrder.organizationId !== organizationId) {
        console.error(`   ❌ MISMATCH! Expected: ${organizationId}, Got: ${verifyOrder.organizationId}`);
      }
    }

    // Если есть товары - добавляем их
    if (data.items && data.items.length > 0) {
      await this.orderItemsService.createOrderItems(savedOrder.id, data.items, options);
      
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
    data: Partial<Order> & {
      items?: Array<{ itemId: number; quantity: number }>;
      workStages?: OrderWorkStage[];
    },
    actor?: { userId?: string; id?: string },
  ) {
    const existingOrder = await this.findOne(id, organizationId); // Проверка существования

    // Извлекаем items из data, чтобы не пытаться обновить relation
    const { items, workStages, ...orderData } = data;

    // Обновляем основные поля заказа
    if (Object.keys(orderData).length > 0) {
      await this.orderRepository.update({ id, organizationId }, orderData);
    }

    let normalizedWorkStages: OrderWorkStage[] | null = null;
    if (workStages) {
      const isServiceOrg = await this.isServiceOrganization(organizationId);
      if (isServiceOrg) {
        normalizedWorkStages = this.normalizeWorkStages(workStages);
        await this.orderRepository.update(
          { id, organizationId },
          { workStages: normalizedWorkStages },
        );
      }
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

    const updatedOrder = await this.findOne(id, organizationId);

    if (
      normalizedWorkStages &&
      updatedOrder.isB2C &&
      updatedOrder.customerId
    ) {
      await this.notifyB2CWorkStageUpdate(
        updatedOrder,
        existingOrder.workStages || [],
        normalizedWorkStages,
        actor,
      );
    }

    return updatedOrder;
  }

  async remove(id: number, organizationId: string) {
    await this.findOne(id, organizationId); // Проверка существования
    await this.orderRepository.delete({ id, organizationId });
    return { success: true };
  }

  // Метод для отладки - получить все заказы
  async findAllForDebug() {
    return await this.orderRepository.find({
      relations: ['customer', 'items', 'items.item', 'organization'],
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  private getDefaultWorkStages(): OrderWorkStage[] {
    return [
      { id: 'disassembly', title: 'Разбор', items: [] },
      { id: 'repair', title: 'Ремонт', items: [] },
      { id: 'prep', title: 'Подготовка', items: [] },
      { id: 'paint', title: 'Покраска', items: [] },
      { id: 'assembly', title: 'Сбор', items: [] },
      { id: 'polish', title: 'Полировка/Мойка', items: [] },
      { id: 'done', title: 'Готово', items: [] },
    ];
  }

  private normalizeWorkStages(stages: OrderWorkStage[]): OrderWorkStage[] {
    return stages.map((stage) => ({
      id: stage.id || this.slugify(stage.title),
      title: stage.title,
      items: (stage.items || []).map((item) => ({
        id: item.id || this.slugify(item.title),
        title: item.title,
        done: Boolean(item.done),
        doneAt: item.doneAt || null,
      })),
    }));
  }

  private async notifyB2CWorkStageUpdate(
    order: Order,
    previousStages: OrderWorkStage[],
    nextStages: OrderWorkStage[],
    actor?: { userId?: string; id?: string },
  ) {
    const actorUserId = actor?.userId || actor?.id;
    if (!actorUserId) {
      return;
    }

    const changes = this.getWorkStageChanges(previousStages, nextStages);
    if (changes.length === 0) {
      return;
    }

    try {
      const customer =
        order.customer ||
        (await this.customersService.findOne(
          order.customerId,
          order.organizationId,
        ));

      if (!customer?.phone) {
        return;
      }

      if (!this.whatsAppService.isClientReady(actorUserId)) {
        return;
      }

      const stageLines = changes.map(
        (change) => `- ${change.stageTitle}: ${change.done}/${change.total}`,
      );

      const completedItems = changes
        .flatMap((change) =>
          change.completedItems.map((title) => `${change.stageTitle}: ${title}`),
        )
        .slice(0, 6);

      const messageLines = [
        `Обновление заказ-наряда ${order.orderNumber || `#${order.id}`}.`,
        'Этапы работ:',
        ...stageLines,
      ];

      if (completedItems.length > 0) {
        messageLines.push('Завершено:');
        messageLines.push(...completedItems.map((item) => `- ${item}`));
      }

      await this.whatsAppService.sendMessage(
        actorUserId,
        customer.phone,
        messageLines.join('\n'),
      );
    } catch (error) {
      console.error('❌ Ошибка отправки уведомления B2C:', error.message);
    }
  }

  private getWorkStageChanges(
    previousStages: OrderWorkStage[],
    nextStages: OrderWorkStage[],
  ) {
    const previousByStage = new Map(
      previousStages.map((stage) => [stage.id, stage]),
    );

    const changes: Array<{
      stageTitle: string;
      done: number;
      total: number;
      completedItems: string[];
    }> = [];

    for (const stage of nextStages) {
      const prevStage = previousByStage.get(stage.id);
      const prevItems = new Map(
        (prevStage?.items || []).map((item) => [item.id, item]),
      );

      const completedItems: string[] = [];
      for (const item of stage.items || []) {
        const prevItem = prevItems.get(item.id);
        if (!prevItem?.done && item.done) {
          completedItems.push(item.title);
        }
      }

      if (completedItems.length > 0) {
        const done = stage.items.filter((item) => item.done).length;
        const total = stage.items.length;
        changes.push({
          stageTitle: stage.title,
          done,
          total,
          completedItems,
        });
      }
    }

    return changes;
  }

  private slugify(value: string): string {
    return value
      .toLowerCase()
      .replace(/[^a-z0-9а-яё]+/gi, '-')
      .replace(/^-+|-+$/g, '');
  }

  private async isServiceOrganization(organizationId: string): Promise<boolean> {
    try {
      const organization = await this.organizationsService.findOne(organizationId);
      return organization.businessType === BusinessType.SERVICE;
    } catch (error) {
      return false;
    }
  }
}

