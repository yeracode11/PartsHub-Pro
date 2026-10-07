import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Warehouse } from '../warehouses/entities/warehouse.entity';
import {
  LocationKind,
  WarehouseLocation,
} from './entities/warehouse-location.entity';

export interface CreateLocationInput {
  warehouseId?: unknown;
  parentId?: unknown;
  kind?: unknown;
  code?: unknown;
  barcode?: unknown;
}

@Injectable()
export class WarehouseLocationsService {
  constructor(
    @InjectRepository(WarehouseLocation)
    private readonly locationRepository: Repository<WarehouseLocation>,
    @InjectRepository(Warehouse)
    private readonly warehouseRepository: Repository<Warehouse>,
  ) {}

  async list(organizationId: string, warehouseId?: string) {
    return this.locationRepository.find({
      where: {
        organizationId,
        ...(warehouseId ? { warehouseId } : {}),
      },
      order: { code: 'ASC' },
    });
  }

  async create(organizationId: string, raw: CreateLocationInput) {
    const warehouseId = this.text(raw.warehouseId, 'Склад');
    const warehouse = await this.warehouseRepository.findOne({
      where: { id: warehouseId, organizationId },
    });
    if (!warehouse) throw new NotFoundException('Склад не найден');

    const kind = raw.kind ?? LocationKind.CELL;
    if (!Object.values(LocationKind).includes(kind as LocationKind)) {
      throw new BadRequestException('Неизвестный тип ячейки');
    }
    const code = this.text(raw.code, 'Код');
    const barcode = this.optional(raw.barcode);
    const parentId = this.optional(raw.parentId);
    if (parentId) {
      const parent = await this.locationRepository.findOne({
        where: { id: parentId, organizationId, warehouseId },
      });
      if (!parent)
        throw new NotFoundException('Родительская ячейка не найдена');
    }

    try {
      return await this.locationRepository.save(
        this.locationRepository.create({
          organizationId,
          warehouseId,
          parentId,
          kind: kind as LocationKind,
          code,
          barcode,
        }),
      );
    } catch (error) {
      const constraint = (error as { constraint?: string }).constraint;
      if (constraint === 'UQ_warehouse_locations_code') {
        throw new ConflictException('Такой код уже есть на этом складе');
      }
      if (constraint === 'UQ_warehouse_locations_barcode') {
        throw new ConflictException('Такой штрихкод ячейки уже есть');
      }
      throw error;
    }
  }

  async remove(id: string, organizationId: string) {
    const location = await this.locationRepository.findOne({
      where: { id, organizationId },
    });
    if (!location) throw new NotFoundException('Ячейка не найдена');
    const children = await this.locationRepository.count({
      where: { parentId: id, organizationId },
    });
    if (children > 0) {
      throw new BadRequestException('Сначала уберите вложенные ячейки');
    }
    await this.locationRepository.delete({ id, organizationId });
    return { success: true };
  }

  private text(value: unknown, field: string) {
    if (typeof value !== 'string' || !value.trim()) {
      throw new BadRequestException(`Укажите «${field}»`);
    }
    return value.trim().slice(0, 100);
  }

  private optional(value: unknown) {
    if (value === undefined || value === null || value === '') return null;
    if (typeof value !== 'string') {
      throw new BadRequestException('Неверный формат');
    }
    return value.trim().slice(0, 100) || null;
  }
}
