import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { WorkCatalog } from './entities/work-catalog.entity';
import { OrderWork } from './entities/order-work.entity';
import { User } from '../users/entities/user.entity';

export class WorkCatalogInput {
  name: string;
  normHours?: number;
  pricePerHour?: number;
}

export interface OrderWorkInput {
  workCatalogId?: number | null;
  name?: string;
  normHours?: number;
  pricePerHour?: number;
  performerId?: string | null;
  done?: boolean;
}

@Injectable()
export class WorksService {
  constructor(
    @InjectRepository(WorkCatalog)
    private readonly catalogRepository: Repository<WorkCatalog>,
    @InjectRepository(OrderWork)
    private readonly orderWorkRepository: Repository<OrderWork>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findCatalog(organizationId: string): Promise<WorkCatalog[]> {
    return this.catalogRepository.find({
      where: { organizationId, isActive: true },
      order: { name: 'ASC' },
    });
  }

  async createCatalog(
    organizationId: string,
    input: WorkCatalogInput,
  ): Promise<WorkCatalog> {
    const name = (input.name || '').trim();
    if (!name) {
      throw new BadRequestException('Укажите название работы');
    }
    const entry = this.catalogRepository.create({
      organizationId,
      name,
      normHours: this.positiveNumber(input.normHours, 1),
      pricePerHour: this.nonNegativeNumber(input.pricePerHour, 0),
    });
    return this.catalogRepository.save(entry);
  }

  async updateCatalog(
    id: number,
    organizationId: string,
    input: WorkCatalogInput,
  ): Promise<WorkCatalog> {
    const entry = await this.catalogRepository.findOne({
      where: { id, organizationId },
    });
    if (!entry) {
      throw new NotFoundException('Работа не найдена');
    }
    const name = (input.name || '').trim();
    if (!name) {
      throw new BadRequestException('Укажите название работы');
    }
    entry.name = name;
    entry.normHours = this.positiveNumber(input.normHours, entry.normHours);
    entry.pricePerHour = this.nonNegativeNumber(
      input.pricePerHour,
      entry.pricePerHour,
    );
    return this.catalogRepository.save(entry);
  }

  async removeCatalog(id: number, organizationId: string): Promise<void> {
    const entry = await this.catalogRepository.findOne({
      where: { id, organizationId },
    });
    if (!entry) {
      throw new NotFoundException('Работа не найдена');
    }
    entry.isActive = false;
    await this.catalogRepository.save(entry);
  }

  /**
   * Полностью заменяет работы заказа переданным списком.
   * Возвращает сумму работ.
   */
  async replaceOrderWorks(
    orderId: number,
    organizationId: string,
    inputs: OrderWorkInput[],
  ): Promise<number> {
    await this.orderWorkRepository.delete({ orderId });
    if (!inputs || inputs.length === 0) {
      return 0;
    }

    let total = 0;
    for (const input of inputs) {
      const resolved = await this.resolveWorkInput(organizationId, input);
      const subtotal = this.roundMoney(resolved.normHours * resolved.pricePerHour);
      total += subtotal;

      const performerId = await this.resolvePerformer(
        organizationId,
        input.performerId,
      );

      const work = this.orderWorkRepository.create({
        orderId,
        workCatalogId: resolved.workCatalogId,
        name: resolved.name,
        normHours: resolved.normHours,
        pricePerHour: resolved.pricePerHour,
        subtotal,
        performerId,
        done: Boolean(input.done),
      });
      await this.orderWorkRepository.save(work);
    }
    return this.roundMoney(total);
  }

  async getOrderWorks(orderId: number): Promise<OrderWork[]> {
    return this.orderWorkRepository.find({
      where: { orderId },
      relations: ['performer'],
      order: { id: 'ASC' },
    });
  }

  async calculateWorksTotal(orderId: number): Promise<number> {
    const works = await this.orderWorkRepository.find({ where: { orderId } });
    return this.roundMoney(
      works.reduce((sum, work) => sum + Number(work.subtotal), 0),
    );
  }

  private async resolveWorkInput(
    organizationId: string,
    input: OrderWorkInput,
  ): Promise<{
    workCatalogId: number | null;
    name: string;
    normHours: number;
    pricePerHour: number;
  }> {
    if (input.workCatalogId) {
      const catalog = await this.catalogRepository.findOne({
        where: { id: input.workCatalogId, organizationId, isActive: true },
      });
      if (!catalog) {
        throw new BadRequestException('Работа из справочника не найдена');
      }
      return {
        workCatalogId: catalog.id,
        name: catalog.name,
        normHours: this.positiveNumber(input.normHours, catalog.normHours),
        pricePerHour: this.nonNegativeNumber(
          input.pricePerHour,
          catalog.pricePerHour,
        ),
      };
    }

    const name = (input.name || '').trim();
    if (!name) {
      throw new BadRequestException('Укажите название работы');
    }
    return {
      workCatalogId: null,
      name,
      normHours: this.positiveNumber(input.normHours, 1),
      pricePerHour: this.nonNegativeNumber(input.pricePerHour, 0),
    };
  }

  private async resolvePerformer(
    organizationId: string,
    performerId?: string | null,
  ): Promise<string | null> {
    if (!performerId) {
      return null;
    }
    const count = await this.userRepository.count({
      where: { id: performerId, organizationId, isActive: true },
    });
    if (count === 0) {
      throw new BadRequestException('Исполнитель не найден в вашей организации');
    }
    return performerId;
  }

  private positiveNumber(value: unknown, fallback: number): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return Number(fallback) || 1;
    }
    return parsed;
  }

  private nonNegativeNumber(value: unknown, fallback: number): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0) {
      return Number(fallback) || 0;
    }
    return parsed;
  }

  private roundMoney(value: number): number {
    return Math.round(value * 100) / 100;
  }
}
