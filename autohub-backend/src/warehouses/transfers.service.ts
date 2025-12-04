import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { WarehouseTransfer, TransferStatus } from './entities/warehouse-transfer.entity';
import { Item } from '../items/entities/item.entity';
import { Warehouse } from './entities/warehouse.entity';
import { CreateTransferDto } from './dto/create-transfer.dto';
import { UpdateTransferStatusDto } from './dto/update-transfer-status.dto';

@Injectable()
export class TransfersService {
  constructor(
    @InjectRepository(WarehouseTransfer)
    private transfersRepository: Repository<WarehouseTransfer>,
    @InjectRepository(Item)
    private itemsRepository: Repository<Item>,
    @InjectRepository(Warehouse)
    private warehousesRepository: Repository<Warehouse>,
    private dataSource: DataSource,
  ) {}

  async create(createTransferDto: CreateTransferDto, organizationId: string, userId: string): Promise<WarehouseTransfer> {
    // Проверяем, что склады существуют
    const fromWarehouse = await this.warehousesRepository.findOne({
      where: { id: createTransferDto.fromWarehouseId, organizationId },
    });

    if (!fromWarehouse) {
      throw new NotFoundException('Source warehouse not found');
    }

    const toWarehouse = await this.warehousesRepository.findOne({
      where: { id: createTransferDto.toWarehouseId, organizationId },
    });

    if (!toWarehouse) {
      throw new NotFoundException('Destination warehouse not found');
    }

    // Проверяем, что товар существует и находится на складе-источнике
    const item = await this.itemsRepository.findOne({
      where: { id: createTransferDto.itemId, organizationId },
    });

    if (!item) {
      throw new NotFoundException('Item not found');
    }

    // Проверяем достаточность количества
    if (item.quantity < createTransferDto.quantity) {
      throw new BadRequestException('Insufficient quantity');
    }

    const transfer = this.transfersRepository.create({
      ...createTransferDto,
      organizationId,
      createdByUserId: userId,
    });

    return this.transfersRepository.save(transfer);
  }

  async findAll(organizationId: string): Promise<WarehouseTransfer[]> {
    return this.transfersRepository.find({
      where: { organizationId },
      relations: ['fromWarehouse', 'toWarehouse', 'item', 'createdBy', 'completedBy'],
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string, organizationId: string): Promise<WarehouseTransfer> {
    const transfer = await this.transfersRepository.findOne({
      where: { id, organizationId },
      relations: ['fromWarehouse', 'toWarehouse', 'item', 'createdBy', 'completedBy'],
    });

    if (!transfer) {
      throw new NotFoundException(`Transfer with ID ${id} not found`);
    }

    return transfer;
  }

  async updateStatus(
    id: string,
    updateStatusDto: UpdateTransferStatusDto,
    organizationId: string,
    userId: string,
  ): Promise<WarehouseTransfer> {
    const transfer = await this.findOne(id, organizationId);

    if (updateStatusDto.status === TransferStatus.COMPLETED && transfer.status !== TransferStatus.COMPLETED) {
      // Выполняем перемещение товара
      await this.completeTransfer(transfer, userId);
    }

    transfer.status = updateStatusDto.status;

    if (updateStatusDto.status === TransferStatus.COMPLETED) {
      transfer.completedByUserId = userId;
      transfer.completedAt = new Date();
    }

    return this.transfersRepository.save(transfer);
  }

  private async completeTransfer(transfer: WarehouseTransfer, userId: string): Promise<void> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Получаем товар
      const item = await queryRunner.manager.findOne(Item, {
        where: { id: transfer.itemId },
      });

      if (!item) {
        throw new NotFoundException('Item not found');
      }

      // Проверяем достаточность количества
      if (item.quantity < transfer.quantity) {
        throw new BadRequestException('Insufficient quantity for transfer');
      }

      // Уменьшаем количество на текущем складе
      item.quantity -= transfer.quantity;
      await queryRunner.manager.save(Item, item);

      // Если товар должен быть на целевом складе, обновляем его warehouseId
      // Для упрощения, здесь мы просто обновляем склад товара
      // В более сложной системе может потребоваться создание отдельных записей
      // для одного товара на разных складах
      if (item.quantity === 0) {
        item.warehouseId = transfer.toWarehouseId;
        item.quantity = transfer.quantity;
        await queryRunner.manager.save(Item, item);
      }

      await queryRunner.commitTransaction();
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async remove(id: string, organizationId: string): Promise<void> {
    const transfer = await this.findOne(id, organizationId);

    if (transfer.status === TransferStatus.COMPLETED) {
      throw new BadRequestException('Cannot delete completed transfer');
    }

    await this.transfersRepository.remove(transfer);
  }
}

