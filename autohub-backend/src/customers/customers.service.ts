import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
  ) {}

  async findAll(organizationId: string) {
    return await this.customerRepository.find({
      where: { organizationId },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: number, organizationId: string) {
    const customer = await this.customerRepository.findOne({
      where: { id, organizationId },
    });
    if (!customer) {
      throw new Error(`Customer with ID ${id} not found`);
    }
    return customer;
  }

  async create(organizationId: string, data: Partial<Customer>) {
    const customer = this.customerRepository.create({
      ...data,
      organizationId,
    });
    return await this.customerRepository.save(customer);
  }

  async update(id: number, organizationId: string, data: Partial<Customer>) {
    await this.findOne(id, organizationId);
    await this.customerRepository.update({ id, organizationId }, data);
    return await this.findOne(id, organizationId);
  }

  async remove(id: number, organizationId: string) {
    await this.findOne(id, organizationId);
    await this.customerRepository.delete({ id, organizationId });
    return { success: true };
  }

  async getTopCustomers(organizationId: string, limit: number = 10) {
    // Получаем клиентов с их заказами
    const customers = await this.customerRepository.find({
      where: { organizationId },
      relations: ['orders'],
    });

    // Считаем сумму заказов для каждого клиента
    const customersWithStats = customers
      .map((customer) => {
        const totalSpent = customer.orders.reduce(
          (sum, order) => sum + Number(order.totalAmount),
          0,
        );
        const ordersCount = customer.orders.length;

        return {
          id: customer.id,
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
          totalSpent,
          ordersCount,
        };
      })
      .filter((c) => c.totalSpent > 0) // Только клиенты с заказами
      .sort((a, b) => b.totalSpent - a.totalSpent) // Сортируем по убыванию суммы
      .slice(0, limit); // Берем топ N

    return { customers: customersWithStats };
  }
}
