import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Order, OrderWorkStage } from './entities/order.entity';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import { Customer } from '../customers/entities/customer.entity';
import { OrderItemsService } from '../order-items/order-items.service';
import { CustomersService } from '../customers/customers.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { TemplatesService } from '../whatsapp/templates.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { BusinessType } from '../common/enums/business-type.enum';
import { WorksService, OrderWorkInput } from '../works/works.service';

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(Vehicle)
    private readonly vehicleRepository: Repository<Vehicle>,
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
    private readonly orderItemsService: OrderItemsService,
    private readonly customersService: CustomersService,
    private readonly whatsAppService: WhatsAppService,
    private readonly templatesService: TemplatesService,
    private readonly organizationsService: OrganizationsService,
    private readonly worksService: WorksService,
  ) {}

  private readonly orderRelations = [
    'customer',
    'vehicle',
    'items',
    'items.item',
    'works',
    'works.performer',
  ];

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
      relations: this.orderRelations,
      order: { createdAt: 'DESC' },
    });
  }

  // CRUD методы для управления заказами
  async findAll(organizationId: string) {
    const orders = await this.orderRepository.find({
      where: { organizationId },
      relations: this.orderRelations,
      order: { createdAt: 'DESC' },
    });
    return orders;
  }

  async findOne(id: number, organizationId: string) {
    const order = await this.orderRepository.findOne({
      where: { id, organizationId },
      relations: this.orderRelations, // Загружаем товары и работы с полной информацией
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
      works?: OrderWorkInput[];
      workStages?: OrderWorkStage[];
    },
    options?: { skipQuantityCheck?: boolean },
    actor?: { userId?: string; id?: string },
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
    const isB2C = (data as any).isB2C || false;
    const actorUserId = actor?.userId || actor?.id || null;
    const isServiceOrg = await this.isServiceOrganization(organizationId);
    const link = await this.resolveCustomerAndVehicle(
      organizationId,
      data.customerId,
      data.vehicleId,
    );
    const order = this.orderRepository.create({
      orderNumber: data.orderNumber,
      organizationId,
      createdByUserId: actorUserId,
      customerId: link.customerId ?? undefined,
      vehicleId: link.vehicleId ?? undefined,
      status: data.status || 'pending',
      paymentStatus: data.paymentStatus || 'pending',
      notes: data.notes,
      shippingAddress: (data as any).shippingAddress || null, // Адрес доставки для B2C
      isB2C,
      reservedUntil: data.reservedUntil ? new Date(data.reservedUntil as any) : null,
      totalAmount: 0, // Пока 0, посчитаем после добавления товаров
      workStages: isServiceOrg
        ? data.workStages && data.workStages.length > 0
          ? this.normalizeWorkStages(data.workStages)
          : isB2C
            ? this.getDefaultWorkStages()
            : null
        : null,
    });
    const savedOrder = await this.orderRepository.save(order);

    // Если есть товары - добавляем их
    if (data.items && data.items.length > 0) {
      await this.orderItemsService.createOrderItems(savedOrder.id, data.items, options);
    }

    if (data.works && data.works.length > 0) {
      await this.worksService.replaceOrderWorks(
        savedOrder.id,
        organizationId,
        data.works,
      );
    }

    await this.recalculateTotal(savedOrder.id, organizationId);

    const createdOrder = await this.orderRepository.findOne({
      where: { id: savedOrder.id },
      relations: this.orderRelations,
    });

    if (
      createdOrder &&
      createdOrder.status === 'reserved' &&
      createdOrder.isB2C &&
      createdOrder.customerId
    ) {
      await this.notifyB2CReservation(createdOrder, actor);
    }

    // Возвращаем заказ с items
    return createdOrder;
  }


  async update(
    id: number,
    organizationId: string,
    data: Partial<Order> & {
      items?: Array<{ itemId: number; quantity: number }>;
      works?: OrderWorkInput[];
      workStages?: OrderWorkStage[];
    },
    actor?: { userId?: string; id?: string },
  ) {
    const existingOrder = await this.findOne(id, organizationId); // Проверка существования

    // Извлекаем items из data, чтобы не пытаться обновить relation
    const {
      items,
      works,
      workStages,
      id: _id,
      organizationId: _organizationId,
      customer: _customer,
      vehicle: _vehicle,
      organization: _organization,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      ...orderData
    } = data as any;
    const previousStatus = existingOrder.status;
    const previousReservedUntil = existingOrder.reservedUntil;

    if ('customerId' in orderData || 'vehicleId' in orderData) {
      const customerId =
        'customerId' in orderData ? orderData.customerId : existingOrder.customerId;
      // Смена клиента без явного авто сбрасывает авто прежнего владельца.
      const vehicleId =
        'vehicleId' in orderData
          ? orderData.vehicleId
          : customerId === existingOrder.customerId
            ? existingOrder.vehicleId
            : null;
      const link = await this.resolveCustomerAndVehicle(
        organizationId,
        customerId,
        vehicleId,
      );
      orderData.customerId = link.customerId;
      orderData.vehicleId = link.vehicleId;
    }

    if (orderData.reservedUntil) {
      orderData.reservedUntil = new Date(orderData.reservedUntil as any);
    }

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
    }

    if (Array.isArray(works)) {
      await this.worksService.replaceOrderWorks(id, organizationId, works);
    }

    if ((items && items.length > 0) || Array.isArray(works)) {
      await this.recalculateTotal(id, organizationId);
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

    if (
      updatedOrder.isB2C &&
      updatedOrder.customerId &&
      updatedOrder.status !== previousStatus
    ) {
      await this.notifyB2CStatusUpdate(updatedOrder, actor);
    }

    const becameReserved =
      updatedOrder.status === 'reserved' && previousStatus !== 'reserved';
    const addedReserveDate =
      !previousReservedUntil && Boolean(updatedOrder.reservedUntil);

    if (
      updatedOrder.isB2C &&
      updatedOrder.customerId &&
      (becameReserved || addedReserveDate)
    ) {
      await this.notifyB2CReservation(updatedOrder, actor);
    }

    return updatedOrder;
  }

  async remove(id: number, organizationId: string) {
    await this.findOne(id, organizationId); // Проверка существования
    await this.orderRepository.delete({ id, organizationId });
    return { success: true };
  }

  /** Сумма заказа = запчасти + работы. */
  private async recalculateTotal(
    orderId: number,
    organizationId: string,
  ): Promise<void> {
    const partsTotal = await this.orderItemsService.calculateOrderTotal(orderId);
    const worksTotal = await this.worksService.calculateWorksTotal(orderId);
    const totalAmount = Math.round((partsTotal + worksTotal) * 100) / 100;
    await this.orderRepository.update({ id: orderId, organizationId }, { totalAmount });
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
      this.logger.error(
        `Ошибка отправки уведомления B2C: ${error.message}`,
        error.stack,
      );
    }
  }

  private async notifyB2CStatusUpdate(
    order: Order,
    actor?: { userId?: string; id?: string },
  ) {
    const actorUserId = actor?.userId || actor?.id;
    if (!actorUserId) {
      return;
    }

    if (!this.whatsAppService.isClientReady(actorUserId)) {
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

      const businessType = await this.getOrganizationBusinessType(
        order.organizationId,
      );
      if (!businessType) {
        return;
      }

      let templateName: string | null = null;
      if (businessType === BusinessType.SERVICE) {
        templateName = 'Заказ-наряд: обновление статуса';
      } else if (businessType === BusinessType.PARTS) {
        if (order.status === 'completed' || order.status === 'ready') {
          templateName = 'Заказ готов к выдаче (запчасти)';
        }
      }

      if (!templateName) {
        return;
      }

      const template = await this.templatesService.findByName(
        order.organizationId,
        templateName,
      );
      if (!template?.content) {
        return;
      }

      const variables: Record<string, string> = {
        name: customer.name || 'Уважаемый клиент',
        organizationName: await this.getOrganizationName(order.organizationId),
        orderNumber: order.orderNumber || `#${order.id}`,
        status: this.formatStatusLabel(order.status),
      };

      const message = this.templatesService.fillTemplate(
        template.content,
        variables,
      );

      await this.whatsAppService.sendMessage(
        actorUserId,
        customer.phone,
        message,
      );
    } catch (error) {
      this.logger.error(
        `Ошибка отправки статуса заказа: ${error.message}`,
        error.stack,
      );
    }
  }

  private async notifyB2CReservation(
    order: Order,
    actor?: { userId?: string; id?: string },
  ) {
    const actorUserId = actor?.userId || actor?.id;
    if (!actorUserId) {
      return;
    }

    if (!this.whatsAppService.isClientReady(actorUserId)) {
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

      const template = await this.templatesService.findByName(
        order.organizationId,
        'Запчасть забронирована',
      );
      if (!template?.content) {
        return;
      }

      const firstItem = order.items?.[0]?.item;
      const variables: Record<string, string> = {
        name: customer.name || 'Уважаемый клиент',
        organizationName: await this.getOrganizationName(order.organizationId),
        itemName: firstItem?.name || 'Запчасть',
        sku: firstItem?.sku || '—',
        reserveUntil: this.formatReserveUntil(order.reservedUntil),
      };

      const message = this.templatesService.fillTemplate(
        template.content,
        variables,
      );

      await this.whatsAppService.sendMessage(
        actorUserId,
        customer.phone,
        message,
      );
    } catch (error) {
      this.logger.error(
        `Ошибка отправки уведомления о резерве: ${error.message}`,
        error.stack,
      );
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

  private formatReserveUntil(value?: Date | string | null): string {
    if (!value) {
      return 'не указано';
    }
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      return 'не указано';
    }
    return date.toLocaleString('ru-RU', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  private formatStatusLabel(status: string): string {
    switch (status) {
      case 'processing':
        return 'В работе';
      case 'completed':
        return 'Завершен';
      case 'cancelled':
        return 'Отменен';
      case 'reserved':
        return 'Забронирован';
      case 'ready':
        return 'Готов к выдаче';
      default:
        return 'Ожидание';
    }
  }

  private async getOrganizationBusinessType(
    organizationId: string,
  ): Promise<BusinessType | null> {
    try {
      const organization = await this.organizationsService.findOne(
        organizationId,
      );
      return organization.businessType || null;
    } catch (error) {
      return null;
    }
  }

  private async getOrganizationName(organizationId: string): Promise<string> {
    try {
      const organization = await this.organizationsService.findOne(
        organizationId,
      );
      return organization.name || 'наша компания';
    } catch (error) {
      return 'наша компания';
    }
  }

  /**
   * Заказ ↔ клиент ↔ автомобиль: авто должно принадлежать организации и выбранному клиенту.
   * Если указано только авто — клиентом становится его владелец.
   */
  async resolveCustomerAndVehicle(
    organizationId: string,
    customerId?: number | null,
    vehicleId?: number | null,
  ): Promise<{ customerId: number | null; vehicleId: number | null }> {
    const normalizedCustomerId = customerId ? Number(customerId) : null;
    const normalizedVehicleId = vehicleId ? Number(vehicleId) : null;

    if (normalizedCustomerId) {
      const count = await this.customerRepository.count({
        where: { id: normalizedCustomerId, organizationId },
      });
      if (count === 0) {
        throw new BadRequestException('Клиент не найден в вашей организации');
      }
    }

    if (!normalizedVehicleId) {
      return { customerId: normalizedCustomerId, vehicleId: null };
    }

    const vehicle = await this.vehicleRepository.findOne({
      where: { id: normalizedVehicleId, organizationId, isActive: true },
    });
    if (!vehicle) {
      throw new BadRequestException('Автомобиль не найден в вашей организации');
    }
    if (normalizedCustomerId && vehicle.customerId !== normalizedCustomerId) {
      throw new BadRequestException('Автомобиль принадлежит другому клиенту');
    }

    return { customerId: vehicle.customerId, vehicleId: vehicle.id };
  }

  private async isServiceOrganization(organizationId: string): Promise<boolean> {
    const businessType = await this.getOrganizationBusinessType(organizationId);
    return businessType === BusinessType.SERVICE;
  }
}

