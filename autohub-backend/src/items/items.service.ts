import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  Brackets,
  EntityManager,
  Repository,
  SelectQueryBuilder,
} from 'typeorm';
import { Item, ItemStatus } from './entities/item.entity';
import { PartCrossReference } from './entities/part-cross-reference.entity';
import { PartCompatibility } from './entities/part-compatibility.entity';
import {
  escapeLike,
  ItemCatalogInput,
  ItemListQuery,
  parseItemCatalogInput,
  parseItemListQuery,
} from './item-catalog';
import { normalizeOem } from './oem';
import { AuditService, diffFields } from '../audit/audit.service';
import { InventoryService } from '../inventory/inventory.service';
import { MovementType } from '../inventory/entities/inventory-movement.entity';

export interface ItemReadOptions {
  /** Закупочная цена — только для финансовых ролей. */
  includeFinance?: boolean;
}

export interface ItemWriteOptions extends ItemReadOptions {
  actorId?: string | null;
}

const CODE_MATCH_LIMIT = 20;
const ITEM_AUDIT_ENTITY = 'item';
const ITEM_AUDITED_FIELDS = ['price', 'purchaseCost', 'status'] as const;

const isBarcodeConflict = (error: unknown) => {
  const e = error as {
    code?: string;
    constraint?: string;
    driverError?: { constraint?: string };
  };
  return (
    e?.code === '23505' &&
    (e.constraint ?? e.driverError?.constraint) === 'UQ_items_org_barcode'
  );
};

@Injectable()
export class ItemsService {
  constructor(
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    private readonly auditService: AuditService,
    private readonly inventoryService: InventoryService,
  ) {}

  async getPopularItems(organizationId: string, limit: number) {
    const safeLimit = Math.min(Math.max(Number(limit) || 5, 1), 20);
    const rows = await this.itemRepository.manager
      .createQueryBuilder()
      .select('item.id', 'id')
      .addSelect('item.name', 'name')
      .addSelect('item.price', 'price')
      .addSelect('item."imageUrl"', 'imageUrl')
      .addSelect('SUM(oi.quantity)', 'soldCount')
      .from('order_items', 'oi')
      .innerJoin('items', 'item', 'item.id = oi."itemId"')
      .innerJoin('orders', 'ord', 'ord.id = oi."orderId"')
      .where('item."organizationId" = :organizationId', { organizationId })
      .andWhere('ord."organizationId" = :organizationId', { organizationId })
      .andWhere(`ord.status <> 'cancelled'`)
      .andWhere(
        `(ord.status IN ('completed', 'returned') OR ord."paymentStatus" = 'paid')`,
      )
      .groupBy('item.id')
      .addGroupBy('item.name')
      .addGroupBy('item.price')
      .addGroupBy('item."imageUrl"')
      .orderBy('SUM(oi.quantity)', 'DESC')
      .limit(safeLimit)
      .getRawMany();

    return {
      items: rows.map((row) => ({
        id: Number(row.id),
        name: row.name,
        soldCount: Number(row.soldCount) || 0,
        price: Number(row.price) || 0,
        imageUrl: row.imageUrl ?? null,
      })),
    };
  }

  /**
   * Список склада. С limit — страница { items, total, limit, offset };
   * без limit — массив, как ждут клиенты до перехода на постраничную загрузку.
   */
  async findAll(
    organizationId: string,
    rawQuery: Record<string, unknown> = {},
    options: ItemReadOptions = {},
  ) {
    const query = parseItemListQuery(rawQuery);
    const qb = this.baseQuery(organizationId, options);
    this.applyFilters(qb, query);

    if (query.limit === undefined) {
      if (query.code) qb.limit(CODE_MATCH_LIMIT);
      return qb.getMany();
    }
    const [items, total] = await qb
      .limit(query.limit)
      .offset(query.offset)
      .getManyAndCount();
    return { items, total, limit: query.limit, offset: query.offset };
  }

  async findOne(
    id: number,
    organizationId: string,
    options: ItemReadOptions = {},
  ) {
    const item = await this.baseQuery(organizationId, options)
      .leftJoinAndSelect('item.crossReferences', 'crossReference')
      .leftJoinAndSelect('item.compatibility', 'fit')
      .andWhere('item.id = :id', { id })
      .addOrderBy('crossReference.id', 'ASC')
      .addOrderBy('fit.id', 'ASC')
      .getOne();
    if (!item) {
      throw new NotFoundException(`Товар #${id} не найден`);
    }
    return item;
  }

  private baseQuery(organizationId: string, options: ItemReadOptions) {
    const qb = this.withDonorSummary(
      this.itemRepository.createQueryBuilder('item'),
    ).where('item.organizationId = :organizationId', { organizationId });
    if (options.includeFinance) qb.addSelect('item.purchaseCost');
    return qb;
  }

  private applyFilters(qb: SelectQueryBuilder<Item>, query: ItemListQuery) {
    if (query.code) {
      const codeNormalized = normalizeOem(query.code);
      qb.andWhere(
        new Brackets((w) => {
          w.where('item.barcode = :code')
            .orWhere('item.sku = :code')
            .orWhere('item.internalCode = :code');
          if (codeNormalized) {
            w.orWhere('item.oemNormalized = :codeNormalized');
          }
        }),
        { code: query.code, codeNormalized },
      );
    }
    if (query.sku) {
      qb.andWhere('item.sku = :sku', { sku: query.sku });
    }
    if (query.search && !query.sku) {
      this.applySearch(qb, query.search);
    } else {
      qb.orderBy('item.createdAt', 'DESC');
    }
    if (query.category) {
      qb.andWhere('item.category = :category', { category: query.category });
    }
    if (query.categories) {
      qb.andWhere('item.category IN (:...categories)', {
        categories: query.categories,
      });
    }
    if (query.condition) {
      qb.andWhere('item.condition = :condition', {
        condition: query.condition,
      });
    }
    if (query.status) {
      qb.andWhere('item.status = :status', { status: query.status });
    }
    if (query.minPrice !== undefined) {
      qb.andWhere('item.price >= :minPrice', { minPrice: query.minPrice });
    }
    if (query.maxPrice !== undefined) {
      qb.andWhere('item.price <= :maxPrice', { maxPrice: query.maxPrice });
    }
    if (query.warehouseId) {
      qb.andWhere('item.warehouseId = :warehouseId', {
        warehouseId: query.warehouseId,
      });
    }
    if (query.inStock !== undefined) {
      qb.andWhere(query.inStock ? 'item.quantity > 0' : 'item.quantity = 0');
    }
    if (query.minQuantity !== undefined) {
      qb.andWhere('item.quantity >= :minQuantity', {
        minQuantity: query.minQuantity,
      });
    }
    if (query.maxQuantity !== undefined) {
      qb.andWhere('item.quantity <= :maxQuantity', {
        maxQuantity: query.maxQuantity,
      });
    }
    if (query.syncedToB2C !== undefined) {
      qb.andWhere('item.syncedToB2C = :syncedToB2C', {
        syncedToB2C: query.syncedToB2C,
      });
    }
  }

  /**
   * Название, артикул, бренд — по подстроке; штрихкод и внутренний код — точно;
   * OEM и номера аналогов — по нормализованной подстроке.
   * Совпадения собираются через UNION, чтобы каждая ветка шла по своему индексу
   * (OR с подзапросом по аналогам заставляет Postgres читать всю таблицу).
   * Сначала точные совпадения кода, потом названия с начала строки.
   */
  private applySearch(qb: SelectQueryBuilder<Item>, search: string) {
    const searchNormalized = normalizeOem(search) ?? '';
    const byOem = searchNormalized
      ? `OR i."oemNormalized" LIKE :searchNormalizedLike ESCAPE '\\'`
      : '';
    const byCrossReference = searchNormalized
      ? `UNION
         SELECT x."itemId" FROM part_cross_references x
         WHERE x."organizationId" = :organizationId
           AND x."oemNormalized" LIKE :searchNormalizedLike ESCAPE '\\'`
      : '';
    qb.andWhere(
      `item.id IN (
        SELECT i.id FROM items i
        WHERE i."organizationId" = :organizationId
          AND (i.name ILIKE :searchLike ESCAPE '\\'
            OR i.sku ILIKE :searchLike ESCAPE '\\'
            OR i.brand ILIKE :searchLike ESCAPE '\\'
            OR i.barcode = :search
            OR i."internalCode" = :search ${byOem})
        ${byCrossReference}
      )`,
      {
        search,
        searchLike: `%${escapeLike(search)}%`,
        searchPrefix: `${escapeLike(search)}%`,
        searchNormalized,
        searchNormalizedLike: `%${searchNormalized}%`,
      },
    );
    qb.orderBy(
      `CASE
        WHEN item.barcode = :search OR item.internalCode = :search
          OR item.oemNormalized = :searchNormalized OR LOWER(item.sku) = LOWER(:search) THEN 0
        WHEN item.name ILIKE :searchPrefix ESCAPE '\\' THEN 1
        ELSE 2
      END`,
      'ASC',
    ).addOrderBy('item.createdAt', 'DESC');
  }

  /** «Из какой машины деталь»: только название донора, без его финансов. */
  private withDonorSummary(queryBuilder: SelectQueryBuilder<Item>) {
    return queryBuilder
      .leftJoin(
        'item.donor',
        'donor',
        'donor.organizationId = item.organizationId',
      )
      .addSelect([
        'donor.id',
        'donor.brand',
        'donor.model',
        'donor.generation',
        'donor.year',
      ]);
  }

  /** Без связей и финансов — для операций с фото и флагами. */
  private async getItem(id: number, organizationId: string) {
    const item = await this.itemRepository.findOne({
      where: { id, organizationId },
    });
    if (!item) {
      throw new NotFoundException(`Товар #${id} не найден`);
    }
    return item;
  }

  async create(
    organizationId: string,
    data: unknown,
    options: ItemWriteOptions = {},
  ) {
    const input = parseItemCatalogInput(data, {
      canEditCost: !!options.includeFinance,
    });
    const openingQuantity = Number(input.fields.quantity ?? 0);
    delete input.fields.quantity;
    const id = await this.withBarcodeGuard(() =>
      this.itemRepository.manager.transaction(async (manager) => {
        const saved = await manager.save(
          Item,
          manager.create(Item, {
            ...input.fields,
            quantity: 0,
            organizationId,
            syncedToB2C: true, // Автоматически синхронизируем новые товары в B2C
          }),
        );
        await this.replaceRelations(manager, saved.id, organizationId, input);
        if (Number.isInteger(openingQuantity) && openingQuantity > 0) {
          await this.inventoryService.apply(
            {
              organizationId,
              itemId: saved.id,
              type: MovementType.RECEIVING,
              quantityDelta: openingQuantity,
              userId: options.actorId,
              documentType: 'item',
              documentId: String(saved.id),
              reason: 'создание',
            },
            manager,
          );
        }
        return saved.id;
      }),
    );
    return this.findOne(id, organizationId, options);
  }

  async update(
    id: number,
    organizationId: string,
    data: unknown,
    options: ItemWriteOptions = {},
  ) {
    const before = await this.findOne(id, organizationId, {
      includeFinance: true,
    });
    const input = parseItemCatalogInput(data, {
      canEditCost: !!options.includeFinance,
    });
    const requestedQuantity =
      input.fields.quantity === undefined
        ? undefined
        : Number(input.fields.quantity);
    delete input.fields.quantity;

    await this.withBarcodeGuard(() =>
      this.itemRepository.manager.transaction(async (manager) => {
        if (Object.keys(input.fields).length > 0) {
          await manager.update(Item, { id, organizationId }, input.fields);
        }
        await this.replaceRelations(manager, id, organizationId, input);
        if (
          requestedQuantity !== undefined &&
          Number.isInteger(requestedQuantity) &&
          requestedQuantity !== Number(before.quantity)
        ) {
          await this.inventoryService.apply(
            {
              organizationId,
              itemId: id,
              type: MovementType.INVENTORY_ADJUSTMENT,
              quantityDelta: requestedQuantity - Number(before.quantity),
              userId: options.actorId,
              documentType: 'item',
              documentId: String(id),
              reason: 'правка карточки',
            },
            manager,
          );
        }
        await this.auditService.record(
          {
            organizationId,
            userId: options.actorId,
            entityType: ITEM_AUDIT_ENTITY,
            entityId: id,
            action: 'update',
            changes: diffFields(
              { ...before },
              input.fields as Record<string, unknown>,
              ITEM_AUDITED_FIELDS,
            ),
          },
          manager,
        );
      }),
    );
    return this.findOne(id, organizationId, options);
  }

  /** Кроссы и применимость приходят целым списком и заменяют прежний. */
  private async replaceRelations(
    manager: EntityManager,
    itemId: number,
    organizationId: string,
    input: ItemCatalogInput,
  ) {
    if (input.crossReferences) {
      await manager.delete(PartCrossReference, { itemId, organizationId });
      if (input.crossReferences.length > 0) {
        await manager.insert(
          PartCrossReference,
          input.crossReferences.map((ref) => ({
            ...ref,
            itemId,
            organizationId,
          })),
        );
      }
    }
    if (input.compatibility) {
      await manager.delete(PartCompatibility, { itemId, organizationId });
      if (input.compatibility.length > 0) {
        await manager.insert(
          PartCompatibility,
          input.compatibility.map((fit) => ({
            ...fit,
            itemId,
            organizationId,
          })),
        );
      }
    }
  }

  private async withBarcodeGuard<T>(operation: () => Promise<T>): Promise<T> {
    try {
      return await operation();
    } catch (error) {
      if (isBarcodeConflict(error)) {
        throw new ConflictException('Такой штрихкод уже есть у другого товара');
      }
      throw error;
    }
  }

  async remove(id: number, organizationId: string) {
    await this.getItem(id, organizationId);
    await this.itemRepository.delete({ id, organizationId });
    return { success: true };
  }

  // Методы для B2C интеграции
  async findAllForB2C(options: {
    category?: string;
    search?: string;
    limit?: number;
    offset?: number;
  }) {
    const queryBuilder = this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.quantity > 0') // Только товары в наличии
      .andWhere('item.status = :active', { active: ItemStatus.ACTIVE });
    // Временно убираем проверку synced для показа всех товаров

    if (options.category && options.category !== 'Все') {
      queryBuilder.andWhere('item.category = :category', {
        category: options.category,
      });
    }

    if (options.search) {
      queryBuilder.andWhere(
        '(item.name LIKE :search OR item.description LIKE :search OR item.sku LIKE :search)',
        { search: `%${options.search}%` },
      );
    }

    if (options.limit) {
      queryBuilder.limit(options.limit);
    }

    if (options.offset) {
      queryBuilder.offset(options.offset);
    }

    queryBuilder.orderBy('item.createdAt', 'DESC');

    const items = await queryBuilder.getMany();

    return items;
  }

  async getPopularForB2C(limit: number) {
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.quantity > 0')
      .andWhere('item.status = :active', { active: ItemStatus.ACTIVE })
      .orderBy('item.quantity', 'DESC') // Популярность по количеству на складе
      .limit(limit)
      .getMany();
  }

  async findOneForB2C(id: number) {
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.id = :id', { id })
      .andWhere('item.quantity > 0')
      .andWhere('item.status = :active', { active: ItemStatus.ACTIVE })
      // Убираем проверку synced - показываем все товары в наличии
      .getOne();
  }

  // Получить товары по списку ID (для группировки по продавцам)
  async findItemsByIds(itemIds: number[]) {
    if (itemIds.length === 0) {
      return [];
    }
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.id IN (:...itemIds)', { itemIds })
      .andWhere('item.status = :active', { active: ItemStatus.ACTIVE })
      .getMany();
  }

  // Методы для работы с изображениями
  async addImages(id: number, organizationId: string, imageUrls: string[]) {
    const item = await this.getItem(id, organizationId);

    // Инициализируем массив изображений если его нет
    if (!item.images) {
      item.images = [];
    }

    // Добавляем новые изображения
    item.images = [...item.images, ...imageUrls];

    // Если это первое изображение, устанавливаем его как основное
    if (!item.imageUrl && imageUrls.length > 0) {
      item.imageUrl = imageUrls[0];
    }

    return await this.itemRepository.save(item);
  }

  async removeImage(id: number, organizationId: string, imageUrl: string) {
    const item = await this.getItem(id, organizationId);

    if (!item.images) {
      throw new Error('No images found for this item');
    }

    // Удаляем изображение из массива
    item.images = item.images.filter((img) => img !== imageUrl);

    // Если удаляем основное изображение, устанавливаем новое основное
    if (item.imageUrl === imageUrl) {
      item.imageUrl = item.images.length > 0 ? item.images[0] : '';
    }

    return await this.itemRepository.save(item);
  }

  async setMainImage(id: number, organizationId: string, imageUrl: string) {
    const item = await this.getItem(id, organizationId);

    if (!item.images || !item.images.includes(imageUrl)) {
      throw new Error('Image not found in item images');
    }

    item.imageUrl = imageUrl;
    return await this.itemRepository.save(item);
  }

  // Синхронизировать товар в B2C магазин
  async syncToB2C(id: number, organizationId: string) {
    const item = await this.getItem(id, organizationId);
    item.syncedToB2C = true;
    const updatedItem = await this.itemRepository.save(item);

    return updatedItem;
  }

  // Синхронизировать все товары организации в B2C
  async syncAllToB2C(organizationId: string) {
    const items = await this.itemRepository.find({
      where: { organizationId },
    });

    let syncedCount = 0;
    for (const item of items) {
      if (!item.syncedToB2C) {
        item.syncedToB2C = true;
        await this.itemRepository.save(item);
        syncedCount++;
      }
    }

    return {
      synced: syncedCount,
      total: items.length,
      message: `Синхронизировано ${syncedCount} из ${items.length} товаров в B2C магазин`,
    };
  }
}
