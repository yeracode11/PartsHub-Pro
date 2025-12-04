import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Warehouse } from './entities/warehouse.entity';
import { CreateWarehouseDto } from './dto/create-warehouse.dto';
import { UpdateWarehouseDto } from './dto/update-warehouse.dto';

@Injectable()
export class WarehousesService {
  constructor(
    @InjectRepository(Warehouse)
    private warehousesRepository: Repository<Warehouse>,
  ) {}

  async create(createWarehouseDto: CreateWarehouseDto, organizationId: string): Promise<Warehouse> {
    const warehouse = this.warehousesRepository.create({
      ...createWarehouseDto,
      organizationId,
    });
    return this.warehousesRepository.save(warehouse);
  }

  async findAll(organizationId: string): Promise<Warehouse[]> {
    return this.warehousesRepository.find({
      where: { organizationId },
      order: { name: 'ASC' },
    });
  }

  async findOne(id: string, organizationId: string): Promise<Warehouse> {
    const warehouse = await this.warehousesRepository.findOne({
      where: { id, organizationId },
      relations: ['items'],
    });

    if (!warehouse) {
      throw new NotFoundException(`Warehouse with ID ${id} not found`);
    }

    return warehouse;
  }

  async update(id: string, updateWarehouseDto: UpdateWarehouseDto, organizationId: string): Promise<Warehouse> {
    const warehouse = await this.findOne(id, organizationId);
    
    Object.assign(warehouse, updateWarehouseDto);
    
    return this.warehousesRepository.save(warehouse);
  }

  async remove(id: string, organizationId: string): Promise<void> {
    const warehouse = await this.findOne(id, organizationId);
    await this.warehousesRepository.remove(warehouse);
  }

  async getItemsCount(id: string, organizationId: string): Promise<number> {
    const warehouse = await this.warehousesRepository.findOne({
      where: { id, organizationId },
      relations: ['items'],
    });

    if (!warehouse) {
      throw new NotFoundException(`Warehouse with ID ${id} not found`);
    }

    return warehouse.items?.length || 0;
  }
}

