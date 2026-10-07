import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Item } from '../items/entities/item.entity';
import { AuditService, diffFields } from '../audit/audit.service';
import { nextStock } from './stock-balance';
import {
  InventoryMovement,
  MovementType,
} from './entities/inventory-movement.entity';

export interface StockChange {
  organizationId: string;
  itemId: number;
  type: MovementType;
  quantityDelta?: number;
  reservedDelta?: number;
  userId?: string | null;
  documentType?: string | null;
  documentId?: string | null;
  reason?: string | null;
  warehouseId?: string | null;
  locationId?: string | null;
}

const AUDIT_FIELDS = ['quantity', 'reservedQuantity'] as const;

@Injectable()
export class InventoryService {
  constructor(
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    @InjectRepository(InventoryMovement)
    private readonly movementRepository: Repository<InventoryMovement>,
    private readonly dataSource: DataSource,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Единственное место, где меняется остаток и резерв.
   * Строка товара блокируется до конца транзакции.
   */
  async apply(change: StockChange, manager?: EntityManager): Promise<Item> {
    const run = (em: EntityManager) => this.applyLocked(em, change);
    if (manager) return run(manager);
    return this.dataSource.transaction(run);
  }

  async history(organizationId: string, itemId: number) {
    await this.requireItem(itemId, organizationId);
    return this.movementRepository.find({
      where: { organizationId, itemId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  private async applyLocked(manager: EntityManager, change: StockChange) {
    const quantityDelta = change.quantityDelta ?? 0;
    const reservedDelta = change.reservedDelta ?? 0;
    if (!Number.isInteger(quantityDelta) || !Number.isInteger(reservedDelta)) {
      throw new BadRequestException('Некорректное количество');
    }
    if (quantityDelta === 0 && reservedDelta === 0) {
      throw new BadRequestException('Некорректное количество');
    }

    const item = await manager
      .getRepository(Item)
      .createQueryBuilder('item')
      .setLock('pessimistic_write')
      .where('item.id = :id', { id: change.itemId })
      .andWhere('item.organizationId = :organizationId', {
        organizationId: change.organizationId,
      })
      .getOne();
    if (!item) {
      throw new NotFoundException(`Товар #${change.itemId} не найден`);
    }

    const before = {
      quantity: Number(item.quantity),
      reservedQuantity: Number(item.reservedQuantity ?? 0),
    };
    let next;
    try {
      next = nextStock(
        { quantity: before.quantity, reserved: before.reservedQuantity },
        { quantityDelta, reservedDelta },
      );
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw new BadRequestException(
          `Недостаточно на складе: «${item.name}», доступно ${before.quantity - before.reservedQuantity}`,
        );
      }
      throw error;
    }

    await manager.update(
      Item,
      { id: item.id, organizationId: change.organizationId },
      { quantity: next.quantity, reservedQuantity: next.reserved },
    );
    await manager.insert(InventoryMovement, {
      organizationId: change.organizationId,
      itemId: item.id,
      type: change.type,
      quantityDelta,
      quantityAfter: next.quantity,
      reservedDelta,
      reservedAfter: next.reserved,
      warehouseId: change.warehouseId ?? item.warehouseId ?? null,
      locationId: change.locationId ?? item.locationId ?? null,
      documentType: change.documentType ?? null,
      documentId: change.documentId ?? null,
      reason: change.reason ?? null,
      userId: change.userId ?? null,
    });
    await this.auditService.record(
      {
        organizationId: change.organizationId,
        userId: change.userId,
        entityType: 'item',
        entityId: item.id,
        action: change.type,
        changes: diffFields(
          before,
          { quantity: next.quantity, reservedQuantity: next.reserved },
          AUDIT_FIELDS,
        ),
      },
      manager,
    );

    item.quantity = next.quantity;
    item.reservedQuantity = next.reserved;
    item.available = next.quantity - next.reserved;
    return item;
  }

  private async requireItem(itemId: number, organizationId: string) {
    const item = await this.itemRepository.findOne({
      where: { id: itemId, organizationId },
    });
    if (!item) throw new NotFoundException(`Товар #${itemId} не найден`);
    return item;
  }
}
