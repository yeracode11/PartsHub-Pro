import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { Order } from '../orders/entities/order.entity';
import { Item } from '../items/entities/item.entity';
import { OrderItem } from '../order-items/entities/order-item.entity';
import { IncomingDoc, IncomingDocStatus } from '../incoming/entities/incoming-doc.entity';

@Injectable()
export class DashboardService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    @InjectRepository(OrderItem)
    private readonly orderItemRepository: Repository<OrderItem>,
    @InjectRepository(IncomingDoc)
    private readonly incomingDocRepository: Repository<IncomingDoc>,
  ) {}

  async getStats(organizationId: string) {
    // Все заказы организации
    const allOrders = await this.orderRepository.find({
      where: { organizationId },
    });

    // Заказы за текущий месяц
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const monthOrders = allOrders.filter(
      (o) => o.createdAt >= monthStart,
    );

    // Активные заказы (pending или processing)
    const activeOrders = allOrders.filter(
      (o) => o.status === 'pending' || o.status === 'processing',
    );

    // Количество товаров
    const itemCount = await this.itemRepository.count({
      where: { organizationId },
    });

    const totalRevenue = allOrders.reduce(
      (sum, o) => sum + Number(o.totalAmount),
      0,
    );
    const monthlyRevenue = monthOrders.reduce(
      (sum, o) => sum + Number(o.totalAmount),
      0,
    );

    return {
      totalRevenue,
      monthlyRevenue,
      inventoryCount: itemCount,
      activeOrdersCount: activeOrders.length,
      period: now.toISOString().substring(0, 7),
    };
  }

  async getSalesChart(organizationId: string, period: string) {
    const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
    const data: { date: string; amount: number }[] = [];

    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Получаем заказы за период
    const orders = await this.orderRepository.find({
      where: {
        organizationId,
        createdAt: Between(startDate, endDate),
      },
    });

    // Группируем по датам
    for (let i = 0; i < days; i++) {
      const date = new Date();
      date.setDate(date.getDate() - (days - i - 1));
      const dateStr = date.toISOString().substring(0, 10);

      const dayOrders = orders.filter(
        (o) => o.createdAt.toISOString().substring(0, 10) === dateStr,
      );

      const amount = dayOrders.reduce(
        (sum, o) => sum + Number(o.totalAmount),
        0,
      );

      data.push({ date: dateStr, amount });
    }

    return { period, data };
  }

  async getCategoryStats(organizationId: string) {
    // Получаем все товары организации
    const items = await this.itemRepository.find({
      where: { organizationId },
    });

    // Группируем по категориям
    const categoryMap = new Map<string, { count: number; totalValue: number }>();

    for (const item of items) {
      const category = item.category || 'Без категории';
      const current = categoryMap.get(category) || { count: 0, totalValue: 0 };

      categoryMap.set(category, {
        count: current.count + item.quantity,
        totalValue: current.totalValue + Number(item.price) * item.quantity,
      });
    }

    // Преобразуем в массив
    const categories = Array.from(categoryMap.entries()).map(([name, data]) => ({
      category: name,
      count: data.count,
      totalValue: data.totalValue,
    }));

    return { categories };
  }

  // Расширенная аналитика
  async getAdvancedAnalytics(organizationId: string) {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0);

    // Заказы
    const allOrders = await this.orderRepository.find({
      where: { organizationId },
      relations: ['items'],
    });

    const currentMonthOrders = allOrders.filter((o) => o.createdAt >= monthStart);
    const lastMonthOrders = allOrders.filter(
      (o) => o.createdAt >= lastMonthStart && o.createdAt < monthStart,
    );

    // Выручка
    const currentMonthRevenue = currentMonthOrders.reduce(
      (sum, o) => sum + Number(o.totalAmount),
      0,
    );
    const lastMonthRevenue = lastMonthOrders.reduce(
      (sum, o) => sum + Number(o.totalAmount),
      0,
    );
    const revenueChange = lastMonthRevenue > 0
      ? ((currentMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100
      : 0;

    // Количество заказов
    const currentMonthOrdersCount = currentMonthOrders.length;
    const lastMonthOrdersCount = lastMonthOrders.length;
    const ordersChange = lastMonthOrdersCount > 0
      ? ((currentMonthOrdersCount - lastMonthOrdersCount) / lastMonthOrdersCount) * 100
      : 0;

    // Средний чек
    const avgOrderValue = currentMonthOrdersCount > 0
      ? currentMonthRevenue / currentMonthOrdersCount
      : 0;
    const lastMonthAvgOrderValue = lastMonthOrdersCount > 0
      ? lastMonthRevenue / lastMonthOrdersCount
      : 0;
    const avgOrderChange = lastMonthAvgOrderValue > 0
      ? ((avgOrderValue - lastMonthAvgOrderValue) / lastMonthAvgOrderValue) * 100
      : 0;

    // Оплаченные заказы
    const paidOrders = currentMonthOrders.filter((o) => o.paymentStatus === 'paid');
    const paidRevenue = paidOrders.reduce((sum, o) => sum + Number(o.totalAmount), 0);
    const unpaidRevenue = currentMonthRevenue - paidRevenue;

    // Приходные накладные
    const incomingDocs = await this.incomingDocRepository.find({
      where: { organizationId, status: IncomingDocStatus.DONE },
    });

    const currentMonthIncoming = incomingDocs.filter((d) => d.createdAt >= monthStart);
    const incomingAmount = currentMonthIncoming.reduce(
      (sum, d) => sum + Number(d.totalAmount),
      0,
    );

    // Прибыль (выручка - закупки)
    const profit = currentMonthRevenue - incomingAmount;
    const profitMargin = currentMonthRevenue > 0 ? (profit / currentMonthRevenue) * 100 : 0;

    return {
      revenue: {
        current: currentMonthRevenue,
        last: lastMonthRevenue,
        change: revenueChange,
      },
      orders: {
        current: currentMonthOrdersCount,
        last: lastMonthOrdersCount,
        change: ordersChange,
      },
      avgOrderValue: {
        current: avgOrderValue,
        last: lastMonthAvgOrderValue,
        change: avgOrderChange,
      },
      payments: {
        paid: paidRevenue,
        unpaid: unpaidRevenue,
        paidCount: paidOrders.length,
        unpaidCount: currentMonthOrdersCount - paidOrders.length,
      },
      incoming: {
        amount: incomingAmount,
        count: currentMonthIncoming.length,
      },
      profit: {
        amount: profit,
        margin: profitMargin,
      },
    };
  }

  // Топ продаваемых товаров (реально проданных)
  async getTopSellingItems(organizationId: string, limit: number = 10) {
    try {
      const monthStart = new Date();
      monthStart.setDate(1);
      monthStart.setHours(0, 0, 0, 0);

      const orderItems = await this.orderItemRepository
        .createQueryBuilder('orderItem')
        .leftJoinAndSelect('orderItem.item', 'item')
        .leftJoinAndSelect('orderItem.order', 'order')
        .where('order.organizationId = :organizationId', { organizationId })
        .andWhere('order.createdAt >= :monthStart', { monthStart })
        .andWhere('order.createdAt <= :now', { now: new Date() })
        .getMany();

      // Группируем по товарам
      const itemMap = new Map<number, { item: Item; quantity: number; revenue: number }>();

      for (const orderItem of orderItems) {
        if (!orderItem.item || !orderItem.itemId) continue;

        const itemId = orderItem.itemId;
        const subtotal = Number(orderItem.subtotal) || 0;
        const quantity = orderItem.quantity || 0;

        const current = itemMap.get(itemId) || {
          item: orderItem.item,
          quantity: 0,
          revenue: 0,
        };

        itemMap.set(itemId, {
          item: orderItem.item,
          quantity: current.quantity + quantity,
          revenue: current.revenue + subtotal,
        });
      }

      // Сортируем по выручке
      const topItems = Array.from(itemMap.values())
        .sort((a, b) => b.revenue - a.revenue)
        .slice(0, limit)
        .map((data) => ({
          id: data.item.id,
          name: data.item.name || 'Без названия',
          category: data.item.category || null,
          quantity: data.quantity,
          revenue: data.revenue,
          price: Number(data.item.price) || 0,
        }));

      return { items: topItems };
    } catch (error) {
      console.error('Error in getTopSellingItems:', error);
      // Возвращаем пустой массив при ошибке
      return { items: [] };
    }
  }

  // Товары с низким остатком
  async getLowStockItems(organizationId: string, threshold: number = 5) {
    try {
      const items = await this.itemRepository
        .createQueryBuilder('item')
        .where('item.organizationId = :organizationId', { organizationId })
        .andWhere('item.quantity <= :threshold', { threshold })
        .orderBy('item.quantity', 'ASC')
        .limit(20)
        .getMany();

      return {
        items: items.map((item) => ({
          id: item.id,
          name: item.name || 'Без названия',
          category: item.category || null,
          quantity: item.quantity || 0,
          price: Number(item.price) || 0,
          sku: item.sku || null,
        })),
      };
    } catch (error) {
      console.error('Error in getLowStockItems:', error);
      return { items: [] };
    }
  }

  // Статистика продаж по категориям (реальные продажи)
  async getSalesByCategory(organizationId: string) {
    try {
      const monthStart = new Date();
      monthStart.setDate(1);
      monthStart.setHours(0, 0, 0, 0);

      const orderItems = await this.orderItemRepository
        .createQueryBuilder('orderItem')
        .leftJoinAndSelect('orderItem.item', 'item')
        .leftJoinAndSelect('orderItem.order', 'order')
        .where('order.organizationId = :organizationId', { organizationId })
        .andWhere('order.createdAt >= :monthStart', { monthStart })
        .andWhere('order.createdAt <= :now', { now: new Date() })
        .getMany();

      const categoryMap = new Map<string, { quantity: number; revenue: number }>();

      for (const orderItem of orderItems) {
        if (!orderItem.item) continue;

        const category = orderItem.item.category || 'Без категории';
        const current = categoryMap.get(category) || { quantity: 0, revenue: 0 };
        const subtotal = Number(orderItem.subtotal) || 0;
        const quantity = orderItem.quantity || 0;

        categoryMap.set(category, {
          quantity: current.quantity + quantity,
          revenue: current.revenue + subtotal,
        });
      }

      const categories = Array.from(categoryMap.entries()).map(([name, data]) => ({
        category: name,
        quantity: data.quantity,
        revenue: data.revenue,
      }));

      return { categories };
    } catch (error) {
      console.error('Error in getSalesByCategory:', error);
      return { categories: [] };
    }
  }
}

