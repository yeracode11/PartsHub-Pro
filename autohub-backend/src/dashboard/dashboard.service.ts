import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Order } from '../orders/entities/order.entity';
import { Item } from '../items/entities/item.entity';
import { OrderItem } from '../order-items/entities/order-item.entity';
import { IncomingDoc, IncomingDocStatus } from '../incoming/entities/incoming-doc.entity';
import { OrderPayment } from '../orders/entities/order-payment.entity';
import { InventoryMovement, MovementType } from '../inventory/entities/inventory-movement.entity';
import { ItemStatus } from '../items/entities/item.entity';
import { businessToday } from '../donors/donor-status';

/** Не продажа: черновик/корзина, отмена, полный возврат. */
const NOT_SALES = ['draft', 'cart', 'cancelled', 'returned'];
/** Заказ закрыт — больше не «активный». */
const FINISHED = ['delivered', 'completed'];

const DAY_MS = 24 * 60 * 60 * 1000;

function businessTimeZone(): string {
  return process.env.APP_TIME_ZONE?.trim() || 'Asia/Almaty';
}

function percentChange(current: number, previous: number): number {
  return previous > 0 ? ((current - previous) / previous) * 100 : 0;
}

function money(value: string | number | null | undefined): number {
  return Math.round(Number(value ?? 0) * 100) / 100;
}

/** Начало текущего месяца в часовом поясе бизнеса (APP_TIME_ZONE), как момент UTC. */
export function businessMonthStart(now = new Date()): Date {
  const timeZone = businessTimeZone();
  const [year, month] = businessToday(now).split('-').map(Number);
  const guess = Date.UTC(year, month - 1, 1);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(new Date(guess));
  const part = (type: string) =>
    Number(parts.find((p) => p.type === type)?.value ?? 0);
  const zoned = Date.UTC(
    part('year'),
    part('month') - 1,
    part('day'),
    part('hour'),
    part('minute'),
    part('second'),
  );
  return new Date(guess - (zoned - guess));
}

@Injectable()
export class DashboardService {
  private readonly logger = new Logger(DashboardService.name);

  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    @InjectRepository(OrderItem)
    private readonly orderItemRepository: Repository<OrderItem>,
    @InjectRepository(IncomingDoc)
    private readonly incomingDocRepository: Repository<IncomingDoc>,
    @InjectRepository(OrderPayment)
    private readonly orderPaymentRepository: Repository<OrderPayment>,
  ) {}

  /**
   * Деньги на дашборде.
   * - totalRevenue / monthlyRevenue — «продано»: оформленные заказы без отменённых,
   *   возвращённых и черновиков (раньше сюда попадали все заказы).
   * - monthlyPaid — фактически поступило за месяц: оплаты минус возвраты денег.
   * - receivables — долги клиентов: продано, но ещё не оплачено.
   */
  async getStats(organizationId: string) {
    const now = new Date();
    const monthStart = businessMonthStart(now);

    const sold = await this.orderRepository
      .createQueryBuilder('o')
      .select('COALESCE(SUM(o."totalAmount"), 0)', 'total')
      .addSelect(
        'COALESCE(SUM(CASE WHEN o."createdAt" >= :monthStart THEN o."totalAmount" ELSE 0 END), 0)',
        'month',
      )
      .addSelect(
        `COUNT(*) FILTER (WHERE o.status NOT IN (:...finished))`,
        'active',
      )
      .where('o.organizationId = :organizationId', { organizationId })
      .andWhere('o.status NOT IN (:...notSales)', { notSales: NOT_SALES })
      .setParameters({ monthStart, finished: FINISHED })
      .getRawOne<{ total: string; month: string; active: string }>();

    // Подписанная сумма: возврат денег уменьшает поступления.
    const signedAmount = `CASE WHEN p.kind = 'refund' OR p.amount < 0 THEN -ABS(p.amount) ELSE p.amount END`;

    const paid = await this.orderPaymentRepository
      .createQueryBuilder('p')
      .select(`COALESCE(SUM(${signedAmount}), 0)`, 'month')
      .where('p.organizationId = :organizationId', { organizationId })
      .andWhere('p.createdAt >= :monthStart', { monthStart })
      .getRawOne<{ month: string }>();

    const debts = await this.orderRepository
      .createQueryBuilder('o')
      .select(
        `COALESCE(SUM(GREATEST(o."totalAmount" - COALESCE(paid.sum, 0), 0)), 0)`,
        'total',
      )
      .leftJoin(
        (sub) =>
          sub
            .select('p."orderId"', 'orderId')
            .addSelect(`SUM(${signedAmount})`, 'sum')
            .from(OrderPayment, 'p')
            .where('p.organizationId = :organizationId')
            .groupBy('p."orderId"'),
        'paid',
        'paid."orderId" = o.id',
      )
      .where('o.organizationId = :organizationId', { organizationId })
      .andWhere('o.status NOT IN (:...notSales)', { notSales: NOT_SALES })
      .getRawOne<{ total: string }>();

    const itemCount = await this.itemRepository.count({
      where: { organizationId },
    });

    return {
      totalRevenue: money(sold?.total),
      monthlyRevenue: money(sold?.month),
      monthlyPaid: money(paid?.month),
      receivables: money(debts?.total),
      inventoryCount: itemCount,
      activeOrdersCount: Number(sold?.active ?? 0),
      period: businessToday(now).substring(0, 7),
    };
  }

  async getSalesChart(organizationId: string, period: string) {
    const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
    const timeZone = businessTimeZone();
    const now = new Date();
    const since = new Date(now.getTime() - (days + 1) * DAY_MS);

    // Сумма продаж по дням бизнеса (APP_TIME_ZONE), без отмен, возвратов и черновиков.
    const rows = await this.orderRepository
      .createQueryBuilder('o')
      .select(
        // createdAt — timestamp без пояса в часовом поясе самой БД (на проде UTC).
        `to_char((o."createdAt" AT TIME ZONE current_setting('TimeZone')) AT TIME ZONE :timeZone, 'YYYY-MM-DD')`,
        'day',
      )
      .addSelect('SUM(o."totalAmount")', 'amount')
      .where('o.organizationId = :organizationId', { organizationId })
      .andWhere('o.status NOT IN (:...notSales)', { notSales: NOT_SALES })
      .andWhere('o."createdAt" >= :since', { since })
      .setParameter('timeZone', timeZone)
      .groupBy('day')
      .getRawMany<{ day: string; amount: string }>();
    const byDay = new Map(rows.map((row) => [row.day, money(row.amount)]));

    const data: { date: string; amount: number }[] = [];
    for (let i = days - 1; i >= 0; i--) {
      const date = businessToday(new Date(now.getTime() - i * DAY_MS));
      data.push({ date, amount: byDay.get(date) ?? 0 });
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

  // Расширенная аналитика: текущий и прошлый месяц по времени бизнеса.
  async getAdvancedAnalytics(organizationId: string) {
    const now = new Date();
    const monthStart = businessMonthStart(now);
    const lastMonthStart = businessMonthStart(new Date(monthStart.getTime() - 1));

    const totals = await this.orderRepository
      .createQueryBuilder('o')
      .select(
        `COALESCE(SUM(o."totalAmount") FILTER (WHERE o."createdAt" >= :monthStart), 0)`,
        'revenue',
      )
      .addSelect(
        `COALESCE(SUM(o."totalAmount") FILTER (WHERE o."createdAt" < :monthStart), 0)`,
        'lastRevenue',
      )
      .addSelect(`COUNT(*) FILTER (WHERE o."createdAt" >= :monthStart)`, 'orders')
      .addSelect(`COUNT(*) FILTER (WHERE o."createdAt" < :monthStart)`, 'lastOrders')
      .where('o.organizationId = :organizationId', { organizationId })
      .andWhere('o.status NOT IN (:...notSales)', { notSales: NOT_SALES })
      .andWhere('o."createdAt" >= :lastMonthStart', { lastMonthStart })
      .setParameter('monthStart', monthStart)
      .getRawOne<{ revenue: string; lastRevenue: string; orders: string; lastOrders: string }>();

    const revenue = money(totals?.revenue);
    const lastRevenue = money(totals?.lastRevenue);
    const ordersCount = Number(totals?.orders ?? 0);
    const lastOrdersCount = Number(totals?.lastOrders ?? 0);
    const avgOrderValue = ordersCount > 0 ? revenue / ordersCount : 0;
    const lastAvgOrderValue = lastOrdersCount > 0 ? lastRevenue / lastOrdersCount : 0;

    // Себестоимость проданных запчастей — по закупочной цене товара.
    // Позиции без закупочной цены считаем отдельно: прибыль по ним неизвестна.
    const cost = await this.orderItemRepository
      .createQueryBuilder('oi')
      .innerJoin('oi.order', 'o')
      .innerJoin('oi.item', 'i')
      .select(`COALESCE(SUM(oi.quantity * i."purchaseCost"), 0)`, 'cost')
      .addSelect(`COUNT(*) FILTER (WHERE i."purchaseCost" IS NULL)`, 'unknown')
      .where('o.organizationId = :organizationId', { organizationId })
      .andWhere('o.status NOT IN (:...notSales)', { notSales: NOT_SALES })
      .andWhere('o."createdAt" >= :monthStart', { monthStart })
      .getRawOne<{ cost: string; unknown: string }>();
    const costOfGoods = money(cost?.cost);
    const profit = revenue - costOfGoods;

    // Деньги: фактические поступления месяца (оплаты минус возвраты).
    const signedAmount = `CASE WHEN p.kind = 'refund' OR p.amount < 0 THEN -ABS(p.amount) ELSE p.amount END`;
    const paidRow = await this.orderPaymentRepository
      .createQueryBuilder('p')
      .select(`COALESCE(SUM(${signedAmount}), 0)`, 'paid')
      .where('p.organizationId = :organizationId', { organizationId })
      .andWhere('p.createdAt >= :monthStart', { monthStart })
      .getRawOne<{ paid: string }>();
    const paid = money(paidRow?.paid);

    const statusCounts = await this.orderRepository
      .createQueryBuilder('o')
      .select(`COUNT(*) FILTER (WHERE o."paymentStatus" = 'paid')`, 'paid')
      .addSelect(`COUNT(*) FILTER (WHERE o."paymentStatus" <> 'paid')`, 'unpaid')
      .where('o.organizationId = :organizationId', { organizationId })
      .andWhere('o.status NOT IN (:...notSales)', { notSales: NOT_SALES })
      .andWhere('o."createdAt" >= :monthStart', { monthStart })
      .getRawOne<{ paid: string; unpaid: string }>();

    const incoming = await this.incomingDocRepository
      .createQueryBuilder('d')
      .select('COALESCE(SUM(d."totalAmount"), 0)', 'amount')
      .addSelect('COUNT(*)', 'count')
      .where('d.organizationId = :organizationId', { organizationId })
      .andWhere('d.status = :done', { done: IncomingDocStatus.DONE })
      .andWhere('d.createdAt >= :monthStart', { monthStart })
      .getRawOne<{ amount: string; count: string }>();

    return {
      revenue: {
        current: revenue,
        last: lastRevenue,
        change: percentChange(revenue, lastRevenue),
      },
      orders: {
        current: ordersCount,
        last: lastOrdersCount,
        change: percentChange(ordersCount, lastOrdersCount),
      },
      avgOrderValue: {
        current: money(avgOrderValue),
        last: money(lastAvgOrderValue),
        change: percentChange(avgOrderValue, lastAvgOrderValue),
      },
      payments: {
        paid,
        unpaid: money(Math.max(revenue - paid, 0)),
        paidCount: Number(statusCounts?.paid ?? 0),
        unpaidCount: Number(statusCounts?.unpaid ?? 0),
      },
      incoming: {
        amount: money(incoming?.amount),
        count: Number(incoming?.count ?? 0),
      },
      // Валовая прибыль: продажи минус закупочная стоимость проданных запчастей.
      // Зарплата и прочие расходы не вычитаются.
      profit: {
        amount: money(profit),
        margin: revenue > 0 ? (profit / revenue) * 100 : 0,
        costOfGoods,
        itemsWithoutCost: Number(cost?.unknown ?? 0),
      },
    };
  }

  /**
   * Стоимость склада и мёртвый остаток. «Без движения» считаем от последней продажи
   * или поступления (журнал inventory_movements), а если их не было — от появления детали.
   * Архивные товары и нулевой остаток не учитываются.
   */
  async getInventoryValue(organizationId: string, deadDays = 90, limit = 50) {
    const lastActivity = this.itemRepository.manager
      .createQueryBuilder()
      .select('m."itemId"', 'itemId')
      .addSelect('MAX(m."createdAt")', 'at')
      .from(InventoryMovement, 'm')
      .where('m."organizationId" = :organizationId')
      .andWhere('m.type IN (:...activity)')
      .groupBy('m."itemId"');

    const base = () =>
      this.itemRepository
        .createQueryBuilder('i')
        .leftJoin(`(${lastActivity.getQuery()})`, 'act', 'act."itemId" = i.id')
        .where('i.organizationId = :organizationId', { organizationId })
        .andWhere('i.quantity > 0')
        .andWhere('i.status <> :archived', { archived: ItemStatus.ARCHIVED })
        .setParameter('activity', [MovementType.SALE, MovementType.RECEIVING]);

    const idleDays = `GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(act.at, i."createdAt"))))::int`;
    const cost = `i.quantity * i."purchaseCost"`;
    const price = `i.quantity * i.price`;

    const buckets = await base()
      .select(
        `CASE
          WHEN ${idleDays} <= 30 THEN '0-30'
          WHEN ${idleDays} <= 90 THEN '31-90'
          WHEN ${idleDays} <= 180 THEN '91-180'
          WHEN ${idleDays} <= 365 THEN '181-365'
          ELSE '365+' END`,
        'bucket',
      )
      .addSelect('COUNT(*)', 'items')
      .addSelect('SUM(i.quantity)', 'units')
      .addSelect(`COALESCE(SUM(${cost}), 0)`, 'costValue')
      .addSelect(`COALESCE(SUM(${price}), 0)`, 'priceValue')
      .addSelect(`COUNT(*) FILTER (WHERE i."purchaseCost" IS NULL)`, 'withoutCost')
      .groupBy('bucket')
      .getRawMany<Record<string, string>>();

    const order = ['0-30', '31-90', '91-180', '181-365', '365+'];
    const aging = order.map((bucket) => {
      const row = buckets.find((b) => b.bucket === bucket);
      return {
        bucket,
        items: Number(row?.items ?? 0),
        units: Number(row?.units ?? 0),
        costValue: money(row?.costValue),
        priceValue: money(row?.priceValue),
      };
    });
    const totals = aging.reduce(
      (sum, b) => ({
        items: sum.items + b.items,
        units: sum.units + b.units,
        costValue: money(sum.costValue + b.costValue),
        priceValue: money(sum.priceValue + b.priceValue),
      }),
      { items: 0, units: 0, costValue: 0, priceValue: 0 },
    );
    const withoutCost = buckets.reduce((sum, b) => sum + Number(b.withoutCost ?? 0), 0);

    const dead = await base()
      .select('i.id', 'id')
      .addSelect('i.name', 'name')
      .addSelect('i.sku', 'sku')
      .addSelect('i.quantity', 'quantity')
      .addSelect('i.price', 'price')
      .addSelect('i."purchaseCost"', 'purchaseCost')
      .addSelect('i."donorId"', 'donorId')
      .addSelect(idleDays, 'idleDays')
      .addSelect(`${price}`, 'priceValue')
      .andWhere(`${idleDays} >= :deadDays`, { deadDays })
      .orderBy('"priceValue"', 'DESC')
      .limit(limit)
      .getRawMany<Record<string, string | null>>();

    const deadRow = await base()
      .select('COUNT(*)', 'items')
      .addSelect(`COALESCE(SUM(${price}), 0)`, 'priceValue')
      .addSelect(`COALESCE(SUM(${cost}), 0)`, 'costValue')
      .andWhere(`${idleDays} >= :deadDays`, { deadDays })
      .getRawOne<Record<string, string>>();
    const deadTotals = {
      items: Number(deadRow?.items ?? 0),
      priceValue: money(deadRow?.priceValue),
      costValue: money(deadRow?.costValue),
    };

    return {
      totals: { ...totals, withoutCost },
      aging,
      deadDays,
      deadStock: {
        ...deadTotals,
        top: dead.map((row) => ({
          id: Number(row.id),
          name: row.name,
          sku: row.sku,
          quantity: Number(row.quantity),
          price: money(row.price),
          purchaseCost: row.purchaseCost == null ? null : money(row.purchaseCost),
          donorId: row.donorId,
          idleDays: Number(row.idleDays),
          priceValue: money(row.priceValue),
        })),
      },
    };
  }

  // ABC/XYZ анализ товаров
  async getAbcXyz(organizationId: string) {
    const now = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 90);
    startDate.setHours(0, 0, 0, 0);

    const orderItems = await this.orderItemRepository
      .createQueryBuilder('orderItem')
      .leftJoinAndSelect('orderItem.item', 'item')
      .leftJoin('orderItem.order', 'order')
      .where('order.organizationId = :organizationId', { organizationId })
      .andWhere('order.status != :cancelled', { cancelled: 'cancelled' })
      .andWhere('orderItem.createdAt >= :startDate', { startDate })
      .getMany();

    const weekMs = 7 * 24 * 60 * 60 * 1000;
    const totalWeeks = Math.max(
      1,
      Math.ceil((now.getTime() - startDate.getTime()) / weekMs),
    );

    const itemsMap = new Map<
      number,
      {
        id: number;
        name: string;
        sku: string | null;
        revenue: number;
        quantity: number;
        weekly: number[];
      }
    >();

    for (const orderItem of orderItems) {
      const item = orderItem.item;
      if (!item) continue;

      const entry =
        itemsMap.get(item.id) ||
        {
          id: item.id,
          name: item.name,
          sku: item.sku,
          revenue: 0,
          quantity: 0,
          weekly: Array(totalWeeks).fill(0),
        };

      const quantity = Number(orderItem.quantity) || 0;
      const price = Number(orderItem.priceAtTime) || 0;
      const subtotal = quantity * price;

      entry.revenue += subtotal;
      entry.quantity += quantity;

      const createdAt = orderItem.createdAt || now;
      const weekIndex = Math.min(
        totalWeeks - 1,
        Math.max(
          0,
          Math.floor((createdAt.getTime() - startDate.getTime()) / weekMs),
        ),
      );
      entry.weekly[weekIndex] += quantity;

      itemsMap.set(item.id, entry);
    }

    const items = Array.from(itemsMap.values());
    const totalRevenue = items.reduce((sum, item) => sum + item.revenue, 0);

    // ABC классификация
    const sortedByRevenue = [...items].sort((a, b) => b.revenue - a.revenue);
    let cumulative = 0;
    const abcMap = new Map<number, 'A' | 'B' | 'C'>();
    for (const item of sortedByRevenue) {
      const share = totalRevenue > 0 ? item.revenue / totalRevenue : 0;
      cumulative += share;
      if (cumulative <= 0.8) {
        abcMap.set(item.id, 'A');
      } else if (cumulative <= 0.95) {
        abcMap.set(item.id, 'B');
      } else {
        abcMap.set(item.id, 'C');
      }
    }

    // XYZ классификация
    const xyzMap = new Map<number, 'X' | 'Y' | 'Z'>();
    for (const item of items) {
      const mean =
        item.weekly.reduce((sum, value) => sum + value, 0) / totalWeeks;
      const variance =
        item.weekly.reduce((sum, value) => {
          const diff = value - mean;
          return sum + diff * diff;
        }, 0) / totalWeeks;
      const std = Math.sqrt(variance);
      const cv = mean > 0 ? std / mean : Number.POSITIVE_INFINITY;

      if (cv <= 0.5) {
        xyzMap.set(item.id, 'X');
      } else if (cv <= 1) {
        xyzMap.set(item.id, 'Y');
      } else {
        xyzMap.set(item.id, 'Z');
      }
    }

    const summary = {
      A: 0,
      B: 0,
      C: 0,
      X: 0,
      Y: 0,
      Z: 0,
    };

    const resultItems = items
      .map((item) => {
        const abc = abcMap.get(item.id) || 'C';
        const xyz = xyzMap.get(item.id) || 'Z';
        summary[abc] += 1;
        summary[xyz] += 1;
        return {
          id: item.id,
          name: item.name,
          sku: item.sku,
          revenue: item.revenue,
          quantity: item.quantity,
          abc,
          xyz,
        };
      })
      .sort((a, b) => b.revenue - a.revenue);

    return {
      summary,
      items: resultItems.slice(0, 25),
      periodDays: 90,
    };
  }

  async getStaffReport(organizationId: string, period: string) {
    const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const rows = await this.orderRepository
      .createQueryBuilder('order')
      .leftJoin('order.createdBy', 'user')
      .select('user.id', 'userId')
      .addSelect('user.name', 'name')
      .addSelect('user.role', 'role')
      .addSelect('COUNT(order.id)', 'ordersCount')
      .addSelect('SUM(order.totalAmount)', 'revenue')
      .addSelect(
        `SUM(CASE WHEN order.paymentStatus = :paid THEN 1 ELSE 0 END)`,
        'paidCount',
      )
      .where('order.organizationId = :organizationId', { organizationId })
      .andWhere('order.createdByUserId IS NOT NULL')
      .andWhere('order.createdAt BETWEEN :startDate AND :endDate', {
        startDate,
        endDate,
      })
      .setParameters({ paid: 'paid' })
      .groupBy('user.id')
      .addGroupBy('user.name')
      .addGroupBy('user.role')
      .orderBy('revenue', 'DESC')
      .getRawMany();

    const items = rows.map((row) => {
      const ordersCount = Number(row.ordersCount) || 0;
      const revenue = Number(row.revenue) || 0;
      const paidCount = Number(row.paidCount) || 0;
      return {
        userId: row.userId,
        name: row.name,
        role: row.role,
        ordersCount,
        revenue,
        avgCheck: ordersCount > 0 ? revenue / ordersCount : 0,
        conversion: ordersCount > 0 ? paidCount / ordersCount : 0,
      };
    });

    return {
      period,
      items,
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
      this.logger.error('Error in getTopSellingItems', error.stack);
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
      this.logger.error('Error in getLowStockItems', error.stack);
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
      this.logger.error('Error in getSalesByCategory', error.stack);
      return { categories: [] };
    }
  }
}

