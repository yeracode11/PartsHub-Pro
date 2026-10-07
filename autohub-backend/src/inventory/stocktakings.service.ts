import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Item } from '../items/entities/item.entity';
import { Warehouse } from '../warehouses/entities/warehouse.entity';
import { InventoryService } from './inventory.service';
import { MovementType } from './entities/inventory-movement.entity';
import { Stocktaking, StocktakingStatus } from './entities/stocktaking.entity';
import { StocktakingLine } from './entities/stocktaking-line.entity';
import { normalizeOem } from '../items/oem';

@Injectable()
export class StocktakingsService {
  constructor(
    @InjectRepository(Stocktaking)
    private readonly stocktakingRepository: Repository<Stocktaking>,
    @InjectRepository(StocktakingLine)
    private readonly lineRepository: Repository<StocktakingLine>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    @InjectRepository(Warehouse)
    private readonly warehouseRepository: Repository<Warehouse>,
    private readonly inventoryService: InventoryService,
  ) {}

  async create(
    organizationId: string,
    userId: string | null,
    warehouseId: string,
  ) {
    if (!warehouseId) throw new BadRequestException('Укажите склад');
    const warehouse = await this.warehouseRepository.findOne({
      where: { id: warehouseId, organizationId },
    });
    if (!warehouse) throw new NotFoundException('Склад не найден');

    const items = await this.itemRepository.find({
      where: { organizationId, warehouseId },
      order: { name: 'ASC' },
    });
    return this.stocktakingRepository.manager.transaction(async (manager) => {
      const doc = await manager.save(
        Stocktaking,
        manager.create(Stocktaking, {
          organizationId,
          warehouseId,
          status: StocktakingStatus.DRAFT,
          createdByUserId: userId,
        }),
      );
      if (items.length > 0) {
        await manager.insert(
          StocktakingLine,
          items.map((item) => ({
            stocktakingId: doc.id,
            itemId: item.id,
            expectedQuantity: Number(item.quantity),
            countedQuantity: null,
          })),
        );
      }
      return this.getOne(doc.id, organizationId, manager);
    });
  }

  async list(organizationId: string) {
    return this.stocktakingRepository.find({
      where: { organizationId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async findOne(id: string, organizationId: string) {
    return this.getOne(id, organizationId);
  }

  /** Скан или ручной ввод: код и сколько лежит на полке. */
  async count(
    id: string,
    organizationId: string,
    raw: { itemId?: unknown; code?: unknown; countedQuantity?: unknown },
  ) {
    const counted = Number(raw.countedQuantity);
    if (!Number.isInteger(counted) || counted < 0 || counted > 100000) {
      throw new BadRequestException('Укажите фактическое количество');
    }
    const doc = await this.getOne(id, organizationId);
    if (doc.status !== StocktakingStatus.DRAFT) {
      throw new BadRequestException('Инвентаризация уже закрыта');
    }
    const item = await this.findCountedItem(
      organizationId,
      doc.warehouseId,
      raw,
    );
    let line = await this.lineRepository.findOne({
      where: { stocktakingId: doc.id, itemId: item.id },
    });
    if (!line) {
      line = this.lineRepository.create({
        stocktakingId: doc.id,
        itemId: item.id,
        expectedQuantity: Number(item.quantity),
        countedQuantity: counted,
      });
    } else {
      line.countedQuantity = counted;
    }
    await this.lineRepository.save(line);
    return this.getOne(id, organizationId);
  }

  async approve(id: string, organizationId: string, userId: string | null) {
    return this.stocktakingRepository.manager.transaction(async (manager) => {
      const doc = await manager.findOne(Stocktaking, {
        where: { id, organizationId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!doc) throw new NotFoundException('Инвентаризация не найдена');
      if (doc.status !== StocktakingStatus.DRAFT) {
        throw new BadRequestException('Инвентаризация уже закрыта');
      }
      const lines = await manager.find(StocktakingLine, {
        where: { stocktakingId: doc.id },
      });
      for (const line of lines) {
        if (line.countedQuantity === null) continue;
        const item = await manager.findOne(Item, {
          where: { id: line.itemId, organizationId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!item) continue;
        const delta = line.countedQuantity - Number(item.quantity);
        if (delta === 0) continue;
        await this.inventoryService.apply(
          {
            organizationId,
            itemId: item.id,
            type: MovementType.INVENTORY_ADJUSTMENT,
            quantityDelta: delta,
            userId,
            documentType: 'stocktaking',
            documentId: doc.id,
            reason: 'инвентаризация',
          },
          manager,
        );
      }
      doc.status = StocktakingStatus.APPROVED;
      doc.approvedByUserId = userId;
      doc.approvedAt = new Date();
      await manager.save(Stocktaking, doc);
      return this.getOne(doc.id, organizationId, manager);
    });
  }

  private async findCountedItem(
    organizationId: string,
    warehouseId: string,
    raw: { itemId?: unknown; code?: unknown },
  ) {
    const itemId = Number(raw.itemId);
    if (Number.isInteger(itemId) && itemId > 0) {
      const item = await this.itemRepository.findOne({
        where: { id: itemId, organizationId, warehouseId },
      });
      if (!item) throw new NotFoundException('Товар не найден на этом складе');
      return item;
    }
    const code = typeof raw.code === 'string' ? raw.code.trim() : '';
    if (!code) throw new BadRequestException('Укажите товар или код');
    const normalized = normalizeOem(code);
    const item = await this.itemRepository
      .createQueryBuilder('item')
      .where('item.organizationId = :organizationId', { organizationId })
      .andWhere('item.warehouseId = :warehouseId', { warehouseId })
      .andWhere(
        `(item.barcode = :code OR item.sku = :code OR item."internalCode" = :code
          ${normalized ? 'OR item."oemNormalized" = :normalized' : ''})`,
        { code, normalized },
      )
      .getOne();
    if (!item) throw new NotFoundException('Товар с таким кодом не найден');
    return item;
  }

  private async getOne(
    id: string,
    organizationId: string,
    manager = this.stocktakingRepository.manager,
  ) {
    const doc = await manager.findOne(Stocktaking, {
      where: { id, organizationId },
    });
    if (!doc) throw new NotFoundException('Инвентаризация не найдена');
    const lines = await manager.find(StocktakingLine, {
      where: { stocktakingId: id },
      order: { id: 'ASC' },
    });
    const items = lines.length
      ? await manager
          .getRepository(Item)
          .createQueryBuilder('item')
          .select(['item.id', 'item.name', 'item.sku', 'item.barcode'])
          .where('item.id IN (:...ids)', {
            ids: lines.map((line) => line.itemId),
          })
          .andWhere('item.organizationId = :organizationId', { organizationId })
          .getMany()
      : [];
    const byId = new Map(items.map((item) => [item.id, item]));
    return {
      ...doc,
      lines: lines.map((line) => ({
        ...line,
        difference:
          line.countedQuantity === null
            ? null
            : line.countedQuantity - line.expectedQuantity,
        item: byId.get(line.itemId) ?? null,
      })),
    };
  }
}
