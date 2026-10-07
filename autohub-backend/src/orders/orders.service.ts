import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Order, OrderWorkStage } from './entities/order.entity';
import { OrderPayment, OrderPaymentMethod } from './entities/order-payment.entity';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import { Customer } from '../customers/entities/customer.entity';
import { OrderItemsService } from '../order-items/order-items.service';
import { CustomersService } from '../customers/customers.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { TemplatesService } from '../whatsapp/templates.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { BusinessType } from '../common/enums/business-type.enum';
import { WorksService, OrderWorkInput } from '../works/works.service';
import { nextOrderNumber } from './order-number';
import {
  assertOrderTransition,
  nextHold,
  planStockChange,
  StockHold,
} from './order-status';
import { ReservationsService } from './reservations.service';

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
    @InjectRepository(OrderPayment)
    private readonly paymentRepository: Repository<OrderPayment>,
    private readonly reservationsService: ReservationsService,
  ) {}

  private readonly orderRelations = [
    'customer',
    'vehicle',
    'items',
    'items.item',
    'works',
    'works.performer',
    'payments',
  ];

  async getRecentOrders(organizationId: string, limit: number) {
    const safeLimit = Math.min(Math.max(Number(limit) || 5, 1), 20);
    const orders = await this.orderRepository.find({
      where: { organizationId },
      relations: ['customer'],
      order: { createdAt: 'DESC' },
      take: safeLimit,
    });

    return {
      orders: orders.map((order) => ({
        id: order.id,
        orderNumber: order.orderNumber,
        status: order.status,
        paymentStatus: order.paymentStatus,
        totalAmount: Number(order.totalAmount),
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        customer: order.customer
          ? { id: order.customer.id, name: order.customer.name }
          : null,
      })),
    };
  }

  // Получить только заказы из B2C магазина
  async findB2COrders(organizationId: string) {
    const orders = await this.orderRepository.find({
      where: { organizationId, isB2C: true },
      relations: this.orderRelations,
      order: { createdAt: 'DESC' },
    });
    return orders.map((order) => this.decorate(order));
  }

  // CRUD методы для управления заказами
  async findAll(organizationId: string) {
    const orders = await this.orderRepository.find({
      where: { organizationId },
      relations: this.orderRelations,
      order: { createdAt: 'DESC' },
    });
    return orders.map((order) => this.decorate(order));
  }

  async findOne(id: number, organizationId: string) {
    const order = await this.orderRepository.findOne({
      where: { id, organizationId },
      relations: this.orderRelations, // Загружаем товары и работы с полной информацией
    });
    if (!order) {
      throw new Error(`Order with ID ${id} not found`);
    }
    return this.decorate(order);
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
    const isB2C = (data as any).isB2C || false;
    const actorUserId = actor?.userId || actor?.id || null;
    const isServiceOrg = await this.isServiceOrganization(organizationId);
    const link = await this.resolveCustomerAndVehicle(
      organizationId,
      data.customerId,
      data.vehicleId,
    );
    const stockHold: StockHold = options?.skipQuantityCheck
      ? 'none'
      : data.status === 'reserved'
        ? 'reserve'
        : 'sale';
    const order = this.orderRepository.create({
      orderNumber: data.orderNumber || 'ORD-PENDING',
      organizationId,
      createdByUserId: actorUserId,
      customerId: link.customerId ?? undefined,
      vehicleId: link.vehicleId ?? undefined,
      status: data.status || 'pending',
      paymentStatus: data.paymentStatus || 'pending',
      notes: data.notes,
      shippingAddress: (data as any).shippingAddress || null,
      isB2C,
      stockHold,
      reservedUntil: data.reservedUntil ? new Date(data.reservedUntil as any) : null,
      totalAmount: 0,
      workStages: isServiceOrg
        ? data.workStages && data.workStages.length > 0
          ? this.normalizeWorkStages(data.workStages)
          : isB2C
            ? this.getDefaultWorkStages()
            : null
        : null,
    });
    const savedOrder = await this.orderRepository.manager.transaction(async (manager) => {
      if (!data.orderNumber) {
        order.orderNumber = await nextOrderNumber(manager, organizationId);
      }
      const saved = await manager.getRepository(Order).save(order);
      if (data.items && data.items.length > 0) {
        await this.orderItemsService.createOrderItems(
          saved.id,
          organizationId,
          data.items,
          {
            skipQuantityCheck: stockHold === 'none',
            hold: stockHold === 'reserve' ? 'reserve' : 'sale',
          },
          manager,
        );
        if (stockHold === 'reserve') {
          await this.reservationsService.replaceForOrder(manager, {
            organizationId,
            orderId: saved.id,
            userId: actorUserId,
            expiresAt: order.reservedUntil,
            lines: data.items,
          });
        }
      }
      return saved;
    });

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

    return createdOrder ? this.decorate(createdOrder) : createdOrder;
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
      paymentStatus: _paymentStatus,
      payments: _payments,
      paidAmount: _paidAmount,
      dueAmount: _dueAmount,
      ...orderData
    } = data as any;
    const previousStatus = existingOrder.status;
    const previousReservedUntil = existingOrder.reservedUntil;
    const currentHold = (existingOrder.stockHold || 'sale') as StockHold;
    const nextStatus =
      typeof orderData.status === 'string' ? orderData.status : previousStatus;
    if (typeof orderData.status === 'string') {
      assertOrderTransition(previousStatus, nextStatus);
    }

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

    const holdAfter: StockHold | null =
      items && items.length > 0
        ? nextStatus === 'cancelled'
          ? 'none'
          : currentHold === 'none'
            ? 'none'
            : nextStatus === 'reserved'
              ? 'reserve'
              : nextHold(currentHold, nextStatus)
        : nextStatus !== previousStatus
          ? nextHold(currentHold, nextStatus)
          : null;
    if (holdAfter) orderData.stockHold = holdAfter;

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
      await this.orderRepository.manager.transaction(async (manager) => {
        await this.orderItemsService.deleteOrderItems(id, manager, currentHold);
        await this.orderItemsService.createOrderItems(
          id,
          organizationId,
          items,
          {
            skipQuantityCheck: holdAfter === 'none',
            hold: holdAfter === 'reserve' ? 'reserve' : 'sale',
          },
          manager,
        );
        if (holdAfter === 'reserve') {
          await this.reservationsService.replaceForOrder(manager, {
            organizationId,
            orderId: id,
            userId: actor?.id ?? actor?.userId,
            expiresAt: orderData.reservedUntil
              ? new Date(orderData.reservedUntil)
              : existingOrder.reservedUntil,
            lines: items,
          });
        } else if (currentHold === 'reserve') {
          await this.reservationsService.markConverted(id, organizationId, manager);
        }
      });
    } else if (nextStatus !== previousStatus) {
      const plan = planStockChange(currentHold, nextStatus);
      await this.orderRepository.manager.transaction(async (manager) => {
        if (plan === 'release') {
          await this.orderItemsService.releaseLines(id, manager, 'reserve');
          await this.reservationsService.cancelForOrder(id, organizationId, manager);
        } else if (plan === 'restock') {
          await this.orderItemsService.releaseLines(id, manager, 'sale');
        } else if (plan === 'convert') {
          await this.orderItemsService.convertReserveToSale(id, manager);
          await this.reservationsService.markConverted(id, organizationId, manager);
        }
      });
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
    const existing = await this.findOne(id, organizationId);
    const hold = (existing.stockHold || 'sale') as StockHold;
    await this.orderRepository.manager.transaction(async (manager) => {
      await this.orderItemsService.deleteOrderItems(id, manager, hold);
      await this.reservationsService.cancelForOrder(id, organizationId, manager);
      await manager.delete(Order, { id, organizationId });
    });
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
    await this.syncPaymentStatus(orderId, organizationId);
  }

  async addPayment(
    orderId: number,
    organizationId: string,
    input: { amount?: number; method?: string; idempotencyKey?: string },
    actor?: { id?: string },
  ) {
    return this.savePayment(orderId, organizationId, input, 'payment', actor?.id ?? null);
  }

  async refundPayment(
    orderId: number,
    organizationId: string,
    input: { amount?: number; method?: string; idempotencyKey?: string },
    userId?: string | null,
  ) {
    return this.savePayment(orderId, organizationId, input, 'refund', userId ?? null);
  }

  private async savePayment(
    orderId: number,
    organizationId: string,
    input: { amount?: number; method?: string; idempotencyKey?: string },
    kind: 'payment' | 'refund',
    userId: string | null,
  ) {
    const order = await this.orderRepository.findOne({
      where: { id: orderId, organizationId },
    });
    if (!order) {
      throw new NotFoundException('Заказ не найден');
    }

    const key =
      typeof input.idempotencyKey === 'string' && input.idempotencyKey.trim()
        ? input.idempotencyKey.trim().slice(0, 80)
        : null;
    if (key) {
      const existing = await this.paymentRepository.findOne({
        where: { organizationId, idempotencyKey: key },
      });
      if (existing) {
        if (existing.orderId !== orderId) {
          throw new ConflictException('Ключ оплаты уже использован');
        }
        return this.findOne(orderId, organizationId);
      }
    }

    const method = this.parsePaymentMethod(input.method);
    const amount = this.roundMoney(Number(input.amount));
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException(
        kind === 'refund' ? 'Укажите сумму возврата' : 'Укажите сумму оплаты',
      );
    }

    if (kind === 'payment') {
      const due = await this.dueAmount(order);
      if (amount > due + 0.001) {
        throw new BadRequestException('Сумма больше остатка');
      }
    } else {
      const paid = await this.paidAmount(order);
      if (amount > paid + 0.001) {
        throw new BadRequestException('Сумма больше уже оплаченного');
      }
    }

    try {
      await this.paymentRepository.save(
        this.paymentRepository.create({
          organizationId,
          orderId,
          amount,
          method,
          kind,
          idempotencyKey: key,
          createdByUserId: userId,
        }),
      );
    } catch (error) {
      if (key && (error as { code?: string }).code === '23505') {
        return this.findOne(orderId, organizationId);
      }
      throw error;
    }
    await this.syncPaymentStatus(orderId, organizationId);
    return this.findOne(orderId, organizationId);
  }

  async removePayment(orderId: number, paymentId: number, organizationId: string) {
    const payment = await this.paymentRepository.findOne({
      where: { id: paymentId, orderId, organizationId },
    });
    if (!payment) {
      throw new NotFoundException('Оплата не найдена');
    }
    await this.paymentRepository.delete({ id: paymentId, organizationId });
    await this.syncPaymentStatus(orderId, organizationId);
    return this.findOne(orderId, organizationId);
  }

  async paymentSummary(organizationId: string, from: Date, to: Date) {
    const rows = await this.paymentRepository
      .createQueryBuilder('payment')
      .where('payment.organizationId = :organizationId', { organizationId })
      .andWhere('payment.createdAt >= :from', { from })
      .andWhere('payment.createdAt < :to', { to })
      .getMany();

    let cash = 0;
    let card = 0;
    for (const row of rows) {
      if (this.signed(row) < 0 || row.kind === 'refund') {
        const amount = Number(row.amount);
        if (row.method === 'card') card -= amount;
        else cash -= amount;
      } else {
        const amount = Number(row.amount);
        if (row.method === 'card') card += amount;
        else cash += amount;
      }
    }
    return {
      cash: this.roundMoney(cash),
      card: this.roundMoney(card),
      total: this.roundMoney(cash + card),
      count: rows.length,
    };
  }

  private async dueAmount(order: Order): Promise<number> {
    const payments = await this.paymentRepository.find({
      where: { orderId: order.id, organizationId: order.organizationId },
    });
    const paid = this.roundMoney(
      payments.reduce((sum, payment) => sum + this.signed(payment), 0),
    );
    const total = Number(order.totalAmount);
    if (payments.length === 0 && order.paymentStatus === 'paid') {
      return 0;
    }
    return this.roundMoney(Math.max(0, total - paid));
  }

  private async syncPaymentStatus(orderId: number, organizationId: string) {
    const order = await this.orderRepository.findOne({
      where: { id: orderId, organizationId },
    });
    if (!order) return;

    const payments = await this.paymentRepository.find({
      where: { orderId, organizationId },
    });
    const paid = this.roundMoney(
      payments.reduce((sum, payment) => sum + this.signed(payment), 0),
    );
    const total = Number(order.totalAmount);
    const paymentStatus =
      payments.length === 0 || paid <= 0
        ? 'pending'
        : paid + 0.009 >= total
          ? 'paid'
          : 'partially_paid';

    if (payments.length === 0 && order.paymentStatus === 'paid') {
      return;
    }
    if (order.paymentStatus !== paymentStatus) {
      await this.orderRepository.update(
        { id: orderId, organizationId },
        { paymentStatus },
      );
    }
  }

  private decorate(order: Order): Order {
    const rows = Array.isArray(order.payments) ? order.payments : [];
    const payments = rows.map((payment) => ({
      id: payment.id,
      amount: Number(payment.amount),
      method: payment.method,
      kind: payment.kind ?? 'payment',
      createdAt: payment.createdAt,
    }));
    const paidFromRows = this.roundMoney(
      payments.reduce((sum, payment) => sum + this.signed(payment), 0),
    );
    const total = Number(order.totalAmount);
    const paidAmount =
      payments.length === 0 && order.paymentStatus === 'paid' ? total : paidFromRows;
    (order as any).payments = payments;
    (order as any).paidAmount = paidAmount;
    (order as any).dueAmount = this.roundMoney(Math.max(0, total - paidAmount));
    return order;
  }

  private parsePaymentMethod(method?: string): OrderPaymentMethod {
    if (method === 'cash' || method === 'card') return method;
    throw new BadRequestException('Укажите способ оплаты: нал или карта');
  }

  private signed(payment: { amount: number | string; kind?: string | null }) {
    const amount = Number(payment.amount);
    return payment.kind === 'refund' ? -amount : amount;
  }

  private async paidAmount(order: Order): Promise<number> {
    const payments = await this.paymentRepository.find({
      where: { orderId: order.id, organizationId: order.organizationId },
    });
    return this.roundMoney(
      payments.reduce((sum, payment) => sum + this.signed(payment), 0),
    );
  }

  private roundMoney(value: number): number {
    return Math.round(value * 100) / 100;
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

