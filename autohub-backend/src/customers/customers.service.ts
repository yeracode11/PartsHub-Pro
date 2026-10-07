import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';
import { normalizePhoneE164 } from '../common/utils/phone.util';
import { AuditService, diffFields } from '../audit/audit.service';

const CUSTOMER_FIELDS = ['name', 'phone', 'email', 'whatsappPhone', 'companyName', 'notes'] as const;

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
    private readonly auditService: AuditService,
  ) {}

  async findAll(organizationId: string) {
    const customers = await this.customerRepository.find({
      where: { organizationId },
      relations: ['vehicles'],
      order: { createdAt: 'DESC' },
    });

    // Фильтруем только активные автомобили
    return customers.map((customer) => ({
      ...customer,
      vehicles: customer.vehicles
        ? customer.vehicles.filter((v) => v.isActive !== false)
        : [],
    }));
  }

  async findOne(id: number, organizationId: string) {
    const customer = await this.customerRepository.findOne({
      where: { id, organizationId },
      relations: ['vehicles', 'orders'],
    });
    if (!customer) {
      throw new Error(`Customer with ID ${id} not found`);
    }

    if (customer.vehicles) {
      customer.vehicles = customer.vehicles.filter((v) => v.isActive !== false);
    }

    return customer;
  }

  async create(
    organizationId: string,
    data: Partial<Customer>,
    actorId?: string | null,
  ) {
    const fields = this.prepare(data);
    try {
      const saved = await this.customerRepository.save(
        this.customerRepository.create({
          ...fields,
          organizationId,
        }),
      );
      await this.auditService.record({
        organizationId,
        userId: actorId,
        entityType: 'customer',
        entityId: saved.id,
        action: 'create',
        changes: diffFields(null, fields, CUSTOMER_FIELDS),
      });
      return saved;
    } catch (error) {
      this.rethrowPhoneConflict(error);
    }
  }

  async update(
    id: number,
    organizationId: string,
    data: Partial<Customer>,
    actorId?: string | null,
  ) {
    const before = await this.findOne(id, organizationId);
    const fields = this.prepare(data);
    try {
      await this.customerRepository.update({ id, organizationId }, fields);
      await this.auditService.record({
        organizationId,
        userId: actorId,
        entityType: 'customer',
        entityId: id,
        action: 'update',
        changes: diffFields({ ...before }, fields, CUSTOMER_FIELDS),
      });
      return await this.findOne(id, organizationId);
    } catch (error) {
      this.rethrowPhoneConflict(error);
    }
  }

  history(id: number, organizationId: string) {
    return this.auditService.history(organizationId, 'customer', id);
  }

  private prepare(data: Partial<Customer>) {
    const fields: Partial<Customer> = {};
    if (data.name !== undefined) fields.name = String(data.name).trim().slice(0, 255);
    if (data.email !== undefined) fields.email = (data.email?.trim() || null) as string;
    if (data.notes !== undefined) fields.notes = (data.notes?.trim() || null) as string;
    if (data.carModel !== undefined) {
      fields.carModel = (data.carModel?.trim() || null) as string;
    }
    if (data.phone !== undefined) fields.phone = this.phone(data.phone) as string;
    if (data.whatsappPhone !== undefined) {
      fields.whatsappPhone = this.phone(data.whatsappPhone);
    }
    if (data.companyName !== undefined) {
      fields.companyName = data.companyName?.trim().slice(0, 200) || null;
    }
    return fields;
  }

  private phone(value: string | null | undefined) {
    if (value === undefined || value === null || String(value).trim() === '') return null;
    return normalizePhoneE164(String(value));
  }

  private rethrowPhoneConflict(error: unknown): never {
    if ((error as { code?: string }).code === '23505') {
      throw new ConflictException('Клиент с таким телефоном уже есть');
    }
    throw error;
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
