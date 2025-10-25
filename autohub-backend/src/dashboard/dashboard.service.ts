import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { Order } from '../orders/entities/order.entity';
import { Item } from '../items/entities/item.entity';

@Injectable()
export class DashboardService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
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
}

