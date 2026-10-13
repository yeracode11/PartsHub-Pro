import {
  BadRequestException,
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
import { VehicleReferenceService } from '../vehicle-reference/vehicle-reference.service';
import { MovementType } from '../inventory/entities/inventory-movement.entity';

export interface ItemReadOptions {
  /** Закупочная цена — только для финансовых ролей. */
  includeFinance?: boolean;
}

export interface ItemWriteOptions extends ItemReadOptions {
  actorId?: string | null;
}

const CODE_MATCH_LIMIT = 20;
const IMPORT_MAX_ROWS = 5000;
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
    private readonly vehicleReference: VehicleReferenceService,
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
    const id = await this.withBarcodeGuard(() =>
      this.itemRepository.manager.transaction((manager) =>
        this.createWithin(manager, organizationId, input, options),
      ),
    );
    return this.findOne(id, organizationId, options);
  }

  /** Создание товара в чужой транзакции: начальный остаток идёт в журнал склада. */
  private async createWithin(
    manager: EntityManager,
    organizationId: string,
    input: ItemCatalogInput,
    options: ItemWriteOptions,
    reason = 'создание',
  ): Promise<number> {
    const fields = { ...input.fields } as Record<string, unknown>;
    const openingQuantity = Number(fields.quantity ?? 0);
    delete fields.quantity;
    const saved = await manager.save(
      Item,
      manager.create(Item, {
        ...(fields as Partial<Item>),
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
          reason,
        },
        manager,
      );
    }
    return saved.id;
  }

  /**
   * Импорт склада пакетом. dryRun — только проверка и отчёт, без записи.
   * Без dryRun все новые строки создаются в одной транзакции (всё или ничего).
   * Дубль по артикулу или штрихкоду (в базе или выше в файле) пропускается,
   * совпадение по OEM — только предупреждение.
   */
  async importRows(
    organizationId: string,
    body: unknown,
    options: ItemWriteOptions = {},
  ) {
    const payload = (body && typeof body === 'object' ? body : {}) as {
      rows?: unknown;
      dryRun?: unknown;
    };
    if (!Array.isArray(payload.rows) || payload.rows.length === 0) {
      throw new BadRequestException('Нет строк для импорта');
    }
    if (payload.rows.length > IMPORT_MAX_ROWS) {
      throw new BadRequestException(
        `За один раз не больше ${IMPORT_MAX_ROWS} строк — разбейте файл`,
      );
    }
    const dryRun = payload.dryRun !== false;

    type Parsed = {
      row: number;
      name: string;
      input?: ItemCatalogInput;
      status: 'new' | 'duplicate' | 'invalid';
      message?: string;
      existingId?: number;
      warning?: string;
    };
    const parsed: Parsed[] = payload.rows.map((raw, index) => {
      const data = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
      const row = Number(data.row) || index + 2;
      const name = String(data.name ?? '').trim();
      try {
        if (!name) throw new BadRequestException('Нет названия');
        const price = Number(data.price ?? 0);
        if (!Number.isFinite(price) || price < 0) throw new BadRequestException('Неверная цена');
        const quantity = Number(data.quantity ?? 0);
        if (!Number.isInteger(quantity) || quantity < 0) {
          throw new BadRequestException('Количество — целое число от 0');
        }
        const { row: _row, ...fields } = data;
        const input = parseItemCatalogInput(
          { ...fields, name, price, quantity },
          { canEditCost: !!options.includeFinance },
        );
        return { row, name, input, status: 'new' };
      } catch (error) {
        return { row, name, status: 'invalid', message: (error as Error).message };
      }
    });

    const valid = parsed.filter((p) => p.status === 'new');
    const values = (key: 'sku' | 'barcode' | 'oemNormalized') =>
      [
        ...new Set(
          valid
            .map((p) => p.input!.fields[key] as string | null | undefined)
            .filter((v): v is string => !!v && v.trim() !== ''),
        ),
      ];
    const skus = values('sku').map((v) => v.toLowerCase());
    const barcodes = values('barcode');
    const oems = values('oemNormalized');

    const existing = await this.itemRepository
      .createQueryBuilder('i')
      .select(['i.id', 'i.sku', 'i.barcode', 'i.oemNormalized'])
      .where('i.organizationId = :organizationId', { organizationId })
      .andWhere(
        new Brackets((qb) => {
          qb.where('1 = 0');
          if (skus.length) qb.orWhere('LOWER(i.sku) IN (:...skus)', { skus });
          if (barcodes.length) qb.orWhere('i.barcode IN (:...barcodes)', { barcodes });
          if (oems.length) qb.orWhere('i."oemNormalized" IN (:...oems)', { oems });
        }),
      )
      .getMany();
    const bySku = new Map(existing.filter((i) => i.sku).map((i) => [i.sku!.toLowerCase(), i.id]));
    const byBarcode = new Map(existing.filter((i) => i.barcode).map((i) => [i.barcode!, i.id]));
    const byOem = new Map(existing.filter((i) => i.oemNormalized).map((i) => [i.oemNormalized!, i.id]));

    const seenSku = new Map<string, number>();
    const seenBarcode = new Map<string, number>();
    for (const item of valid) {
      const sku = (item.input!.fields.sku as string | null | undefined)?.trim().toLowerCase();
      const barcode = (item.input!.fields.barcode as string | null | undefined)?.trim();
      const oem = item.input!.fields.oemNormalized as string | null | undefined;
      if (sku && bySku.has(sku)) {
        Object.assign(item, { status: 'duplicate', existingId: bySku.get(sku), message: 'Артикул уже есть на складе' });
      } else if (barcode && byBarcode.has(barcode)) {
        Object.assign(item, { status: 'duplicate', existingId: byBarcode.get(barcode), message: 'Штрихкод уже есть на складе' });
      } else if (sku && seenSku.has(sku)) {
        Object.assign(item, { status: 'duplicate', message: `Артикул повторяется в строке ${seenSku.get(sku)}` });
      } else if (barcode && seenBarcode.has(barcode)) {
        Object.assign(item, { status: 'duplicate', message: `Штрихкод повторяется в строке ${seenBarcode.get(barcode)}` });
      } else {
        if (sku) seenSku.set(sku, item.row);
        if (barcode) seenBarcode.set(barcode, item.row);
        if (oem && byOem.has(oem)) item.warning = 'Товар с таким OEM уже есть';
      }
    }

    const toCreate = parsed.filter((p) => p.status === 'new');
    const createdIds = new Map<number, number>();
    if (!dryRun && toCreate.length > 0) {
      await this.withBarcodeGuard(() =>
        this.itemRepository.manager.transaction(async (manager) => {
          for (const item of toCreate) {
            createdIds.set(
              item.row,
              await this.createWithin(manager, organizationId, item.input!, options, 'импорт'),
            );
          }
        }),
      );
    }

    return {
      dryRun,
      total: parsed.length,
      toCreate: toCreate.length,
      created: dryRun ? 0 : toCreate.length,
      duplicates: parsed.filter((p) => p.status === 'duplicate').length,
      invalid: parsed.filter((p) => p.status === 'invalid').length,
      rows: parsed.map((p) => ({
        row: p.row,
        name: p.name,
        status: p.status === 'new' && !dryRun ? 'created' : p.status,
        message: p.message ?? null,
        warning: p.warning ?? null,
        existingId: p.existingId ?? null,
        itemId: createdIds.get(p.row) ?? null,
      })),
    };
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
        const rows: Array<Record<string, unknown>> = [];
        for (const fit of input.compatibility) {
          rows.push({
            ...(await this.vehicleReference.attachCompatibility(fit)),
            itemId,
            organizationId,
          });
        }
        await manager.insert(PartCompatibility, rows);
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
      .andWhere('item.status = :active', { active: ItemStatus.ACTIVE })
      .andWhere(
        `NOT EXISTS (
          SELECT 1 FROM listings l
          WHERE l."itemId" = item.id
            AND l.channel = 'catalog'
            AND l.status IN ('paused', 'archived')
        )`,
      );

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
