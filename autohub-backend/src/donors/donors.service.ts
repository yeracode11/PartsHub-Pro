import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { DonorStatus, DonorVehicle } from './entities/donor-vehicle.entity';
import { Item } from '../items/entities/item.entity';
import {
  AddDonorPartsDto,
  CreateDonorDto,
  UpdateDonorDto,
} from './dto/donor.dto';
import {
  allocateDonorCost,
  calculateDonorEconomics,
  DonorEconomics,
  summarizeDonorEconomics,
} from './donor-economics';
import { AuditService, diffFields } from '../audit/audit.service';
import { InventoryService } from '../inventory/inventory.service';
import { MovementType } from '../inventory/entities/inventory-movement.entity';
import { normalizeOem } from '../items/oem';
import { PartCompatibility } from '../items/entities/part-compatibility.entity';
import {
  allowedDonorTransitions,
  businessToday,
  parseDonorStatus,
  planStatusChange,
} from './donor-status';

/** Деньги по заказу считаем полученными, когда заказ завершён или оплачен. */
const SOLD_CONDITION = `o.status <> 'cancelled' AND (o.status IN ('completed', 'returned') OR o."paymentStatus" = 'paid')`;
const PENDING_CONDITION = `o.status <> 'cancelled' AND o.status <> 'returned' AND NOT (o.status = 'completed' OR o."paymentStatus" = 'paid')`;

/** Снятая деталь точно подходит на свою машину-донора. */
export function donorCompatibility(donor: DonorVehicle) {
  const engine = [
    donor.engine,
    donor.engineVolume ? Number(donor.engineVolume).toFixed(1) : null,
  ]
    .filter(Boolean)
    .join(' ');
  return {
    make: donor.brand.slice(0, 50),
    model: donor.model.slice(0, 80),
    generation: donor.generation ?? null,
    yearFrom: donor.year ?? null,
    yearTo: donor.year ?? null,
    body: donor.body ?? null,
    engine: engine ? engine.slice(0, 80) : null,
    transmission: donor.transmission ?? null,
  };
}

const sumWhen = (condition: string, expression: string) =>
  `COALESCE(SUM(CASE WHEN ${condition} THEN ${expression} ELSE 0 END), 0)`;

const COST_FIELDS = [
  'purchasePrice',
  'deliveryCost',
  'dismantlingCost',
  'otherCosts',
] as const;
const FINANCE_FIELDS = [...COST_FIELDS, 'scrapIncome'] as const;
const TEXT_FIELDS = [
  'generation',
  'body',
  'engine',
  'color',
  'source',
  'notes',
] as const;
const AUDITED_FIELDS = [...FINANCE_FIELDS, 'status'] as const;
const AUDIT_ENTITY = 'donor_vehicle';
const INITIAL_STATUSES = [
  DonorStatus.PURCHASED,
  DonorStatus.WAITING_FOR_DISMANTLING,
];

type DonorWithEconomics = DonorVehicle & {
  economics?: DonorEconomics;
  allowedStatuses: DonorStatus[];
};

export const MAX_PHOTOS = 20;

interface PartSales {
  soldQuantity: number;
  soldRevenue: number;
  pendingQuantity: number;
}

const NO_SALES: PartSales = {
  soldQuantity: 0,
  soldRevenue: 0,
  pendingQuantity: 0,
};

@Injectable()
export class DonorsService {
  constructor(
    @InjectRepository(DonorVehicle)
    private readonly donorRepository: Repository<DonorVehicle>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    private readonly dataSource: DataSource,
    private readonly auditService: AuditService,
    private readonly inventoryService: InventoryService,
  ) {}

  async findAll(
    organizationId: string,
    options: { status?: DonorStatus; includeFinance: boolean },
  ) {
    const donors = await this.donorRepository.find({
      where: {
        organizationId,
        ...(options.status ? { status: options.status } : {}),
      },
      order: { createdAt: 'DESC' },
    });
    if (donors.length === 0) return [];

    const economics = await this.loadEconomics(organizationId, donors);
    return donors.map((donor) =>
      this.present(donor, economics.get(donor.id)!, options.includeFinance),
    );
  }

  async getEconomics(id: number, organizationId: string) {
    const donor = await this.getDonor(id, organizationId);
    const economics = await this.loadEconomics(organizationId, [donor]);
    return economics.get(donor.id)!;
  }

  /** Сводка по всем донорам организации (или по статусу) без загрузки деталей. */
  async getEconomicsSummary(organizationId: string, status?: DonorStatus) {
    const donors = await this.donorRepository.find({
      where: { organizationId, ...(status ? { status } : {}) },
    });
    const economics = await this.loadEconomics(organizationId, donors, {
      allDonors: !status,
    });
    return summarizeDonorEconomics([...economics.values()]);
  }

  async getHistory(id: number, organizationId: string) {
    await this.getDonor(id, organizationId);
    return this.auditService.history(organizationId, AUDIT_ENTITY, id);
  }

  async findOne(id: number, organizationId: string, includeFinance: boolean) {
    const donor = await this.getDonor(id, organizationId);
    const [economics, parts] = await Promise.all([
      this.loadEconomics(organizationId, [donor]),
      this.itemRepository.find({
        where: { organizationId, donorId: donor.id },
        order: { createdAt: 'DESC' },
      }),
    ]);
    const salesByItem = await this.loadPartSales(
      organizationId,
      parts.map((p) => p.id),
    );
    const donorEconomics = economics.get(donor.id)!;
    const salesOf = (id: number) => salesByItem.get(id) ?? NO_SALES;

    const unitCosts = allocateDonorCost(
      donorEconomics.totalCost,
      parts.map((part) => ({
        id: part.id,
        price: Number(part.price) || 0,
        units:
          part.quantity +
          salesOf(part.id).soldQuantity +
          salesOf(part.id).pendingQuantity,
      })),
    );

    return {
      ...this.present(donor, donorEconomics, includeFinance),
      parts: parts.map((part) => {
        const { soldQuantity, soldRevenue } = salesOf(part.id);
        const result: Record<string, unknown> = {
          ...part,
          soldQuantity,
          soldRevenue,
        };
        if (includeFinance) {
          const unitCost = unitCosts.get(part.id) ?? 0;
          result.unitCost = unitCost;
          result.realizedProfit =
            Math.round((soldRevenue - unitCost * soldQuantity) * 100) / 100;
        }
        return result;
      }),
    };
  }

  async addPhotos(
    id: number,
    organizationId: string,
    urls: string[],
    includeFinance: boolean,
  ) {
    const donor = await this.getDonor(id, organizationId);
    const photos = [...(donor.photos ?? []), ...urls];
    if (photos.length > MAX_PHOTOS) {
      throw new BadRequestException(
        `У донора может быть не больше ${MAX_PHOTOS} фото`,
      );
    }
    await this.donorRepository.update({ id, organizationId }, { photos });
    return this.findOne(id, organizationId, includeFinance);
  }

  async removePhoto(
    id: number,
    organizationId: string,
    url: string,
    includeFinance: boolean,
  ) {
    const donor = await this.getDonor(id, organizationId);
    const photos = donor.photos ?? [];
    if (!photos.includes(url)) {
      throw new NotFoundException('Фото не найдено');
    }
    await this.donorRepository.update(
      { id, organizationId },
      { photos: photos.filter((p) => p !== url) },
    );
    return this.findOne(id, organizationId, includeFinance);
  }

  async create(
    organizationId: string,
    dto: CreateDonorDto,
    actorId?: string | null,
  ) {
    const status = parseDonorStatus(dto.status) ?? DonorStatus.PURCHASED;
    if (!INITIAL_STATUSES.includes(status)) {
      throw new BadRequestException(
        'Новый донор может быть только купленным или ждущим разбора',
      );
    }
    const donor = this.donorRepository.create({
      ...this.normalize(dto),
      organizationId,
      status,
    });
    const saved = await this.dataSource.transaction(async (manager) => {
      const created = await manager.save(DonorVehicle, donor);
      await this.auditService.record(
        {
          organizationId,
          userId: actorId,
          entityType: AUDIT_ENTITY,
          entityId: created.id,
          action: 'create',
          changes: diffFields(null, { ...created }, AUDITED_FIELDS),
        },
        manager,
      );
      return created;
    });
    return this.findOne(saved.id, organizationId, true);
  }

  async update(
    id: number,
    organizationId: string,
    dto: UpdateDonorDto,
    actorId?: string | null,
  ) {
    const donor = await this.getDonor(id, organizationId);
    const data = this.normalize(dto);

    const status = parseDonorStatus(dto.status);
    if (status) {
      Object.assign(data, planStatusChange(donor, status, this.today()));
    }
    if (dto.dismantlingStartDate !== undefined) {
      data.dismantlingStartDate = dto.dismantlingStartDate || null;
    }
    if (dto.dismantlingEndDate !== undefined) {
      data.dismantlingEndDate = dto.dismantlingEndDate || null;
    }
    const start =
      'dismantlingStartDate' in data
        ? data.dismantlingStartDate
        : donor.dismantlingStartDate;
    const end =
      'dismantlingEndDate' in data
        ? data.dismantlingEndDate
        : donor.dismantlingEndDate;
    if (start && end && String(end) < String(start)) {
      throw new BadRequestException(
        'Разбор не может закончиться раньше, чем начался',
      );
    }

    if (Object.keys(data).length > 0) {
      await this.dataSource.transaction(async (manager) => {
        await manager.update(DonorVehicle, { id, organizationId }, data);
        await this.auditService.record(
          {
            organizationId,
            userId: actorId,
            entityType: AUDIT_ENTITY,
            entityId: id,
            action: 'update',
            changes: diffFields({ ...donor }, data, AUDITED_FIELDS),
          },
          manager,
        );
      });
    }
    return this.findOne(id, organizationId, true);
  }

  async remove(id: number, organizationId: string) {
    await this.getDonor(id, organizationId);
    const partsCount = await this.itemRepository.count({
      where: { organizationId, donorId: id },
    });
    if (partsCount > 0) {
      throw new BadRequestException(
        'С донора уже сняты детали. Удалить нельзя — переведите его в архив.',
      );
    }
    await this.donorRepository.delete({ id, organizationId });
    return { success: true };
  }

  /** Снять детали с донора: каждая деталь становится товаром склада с привязкой к машине. */
  async addParts(
    id: number,
    organizationId: string,
    dto: AddDonorPartsDto,
    actorId?: string | null,
  ) {
    const donor = await this.getDonor(id, organizationId);
    if (donor.status === DonorStatus.ARCHIVED) {
      throw new BadRequestException('Донор в архиве — снимать детали нельзя');
    }

    const origin = this.describeOrigin(donor);
    const created = await this.dataSource.transaction(async (manager) => {
      const drafts = dto.parts.map((part) => ({
        quantity: part.quantity ?? 1,
        item: manager.create(Item, {
          organizationId,
          donorId: donor.id,
          name: part.name.trim(),
          category: part.category?.trim() || null,
          price: part.price,
          quantity: 0,
          condition: part.condition || 'used',
          warehouseCell: part.warehouseCell?.trim() || null,
          sku: part.sku?.trim() || null,
          oem: normalizeOem(part.oem) ? part.oem!.trim() : null,
          oemNormalized: normalizeOem(part.oem),
          description: part.description?.trim()
            ? `${part.description.trim()}\n${origin}`
            : origin,
          syncedToB2C: true,
        }),
      }));
      const saved = await manager.save(
        Item,
        drafts.map((draft) => draft.item),
      );
      for (let i = 0; i < saved.length; i++) {
        if (drafts[i].quantity <= 0) continue;
        const updated = await this.inventoryService.apply(
          {
            organizationId,
            itemId: saved[i].id,
            type: MovementType.RECEIVING,
            quantityDelta: drafts[i].quantity,
            userId: actorId,
            documentType: 'donor',
            documentId: String(donor.id),
            reason: 'снято с донора',
          },
          manager,
        );
        saved[i].quantity = updated.quantity;
      }
      await manager.insert(
        PartCompatibility,
        saved.map((item) => ({
          ...donorCompatibility(donor),
          organizationId,
          itemId: item.id,
        })),
      );

      if (INITIAL_STATUSES.includes(donor.status)) {
        const patch = planStatusChange(
          donor,
          DonorStatus.DISMANTLING,
          this.today(),
        );
        await manager.update(
          DonorVehicle,
          { id: donor.id, organizationId },
          patch,
        );
        await this.auditService.record(
          {
            organizationId,
            userId: actorId,
            entityType: AUDIT_ENTITY,
            entityId: donor.id,
            action: 'update',
            changes: diffFields({ ...donor }, patch, AUDITED_FIELDS),
          },
          manager,
        );
      }
      return saved;
    });

    return created;
  }

  private async getDonor(id: number, organizationId: string) {
    const donor = await this.donorRepository.findOne({
      where: { id, organizationId },
    });
    if (!donor) {
      throw new NotFoundException(`Донор #${id} не найден`);
    }
    return donor;
  }

  /** Только поля карточки; статус и даты разбора меняются через planStatusChange. */
  private normalize(
    dto: CreateDonorDto | UpdateDonorDto,
  ): Partial<DonorVehicle> {
    const data: Partial<DonorVehicle> = {};
    if (dto.brand !== undefined) data.brand = dto.brand.trim();
    if (dto.model !== undefined) data.model = dto.model.trim();
    for (const field of TEXT_FIELDS) {
      if (dto[field] !== undefined) data[field] = dto[field]?.trim() || null;
    }
    if (dto.vin !== undefined) {
      const vin = (dto.vin ?? '').replace(/\s+/g, '').toUpperCase();
      data.vin = vin.length ? vin : null;
    }
    for (const field of ['year', 'mileage', 'engineVolume'] as const) {
      if (dto[field] !== undefined) data[field] = dto[field] ?? null;
    }
    if (dto.transmission !== undefined)
      data.transmission = dto.transmission ?? null;
    if (dto.drivetrain !== undefined) data.drivetrain = dto.drivetrain ?? null;
    for (const field of [...FINANCE_FIELDS]) {
      if (dto[field] !== undefined) data[field] = dto[field] ?? 0;
    }
    if (dto.purchaseDate !== undefined) {
      data.purchaseDate = dto.purchaseDate ? new Date(dto.purchaseDate) : null;
    }
    return data;
  }

  private today() {
    return businessToday();
  }

  private describeOrigin(donor: DonorVehicle): string {
    const car = [donor.brand, donor.model, donor.generation, donor.year]
      .filter(Boolean)
      .join(' ');
    const engine = [
      donor.engine,
      donor.engineVolume ? `${donor.engineVolume} л` : null,
    ]
      .filter(Boolean)
      .join(' ');
    const details = [
      engine ? `двигатель ${engine}` : null,
      donor.body ? `кузов ${donor.body}` : null,
      donor.vin ? `VIN/кузов ${donor.vin}` : null,
      donor.mileage ? `пробег ${donor.mileage} км` : null,
    ].filter(Boolean);
    return `Снято с донора #${donor.id}: ${car}${details.length ? ` (${details.join(', ')})` : ''}`;
  }

  private present(
    donor: DonorVehicle,
    economics: DonorEconomics,
    includeFinance: boolean,
  ) {
    const result: DonorWithEconomics = {
      ...donor,
      allowedStatuses: allowedDonorTransitions(donor.status),
    };
    if (includeFinance) {
      result.economics = economics;
    } else {
      for (const field of FINANCE_FIELDS) delete (result as any)[field];
      (result as any).stock = {
        partsCount: economics.partsCount,
        unitsReceived: economics.unitsReceived,
        unitsInStock: economics.unitsInStock,
        unitsSold: economics.unitsSold,
        unitsReserved: economics.unitsReserved,
        unitsWrittenOff: economics.unitsWrittenOff,
      };
    }
    return result;
  }

  /**
   * Экономика по списку доноров за два агрегирующих запроса, без N+1.
   * allDonors: считать по всем донорам организации, не перечисляя id в запросе.
   */
  private async loadEconomics(
    organizationId: string,
    donors: DonorVehicle[],
    options: { allDonors?: boolean } = {},
  ): Promise<Map<number, DonorEconomics>> {
    if (donors.length === 0) return new Map();
    const ids = donors.map((d) => d.id);
    const donorFilter = options.allDonors
      ? 'i."donorId" IS NOT NULL'
      : 'i."donorId" IN (:...ids)';

    const [stockRows, salesRows] = await Promise.all([
      this.itemRepository
        .createQueryBuilder('i')
        .select('i."donorId"', 'donorId')
        .addSelect('COUNT(*)', 'partsCount')
        .addSelect('COALESCE(SUM(i.quantity), 0)', 'unitsInStock')
        .addSelect('COALESCE(SUM(i.price * i.quantity), 0)', 'stockValue')
        .where('i."organizationId" = :organizationId', { organizationId })
        .andWhere(donorFilter, { ids })
        .groupBy('i."donorId"')
        .getRawMany(),
      this.dataSource
        .createQueryBuilder()
        .select('i."donorId"', 'donorId')
        .addSelect(sumWhen(SOLD_CONDITION, 'oi.subtotal'), 'soldRevenue')
        .addSelect(sumWhen(SOLD_CONDITION, 'oi.quantity'), 'unitsSold')
        .addSelect(
          sumWhen(SOLD_CONDITION, 'i.price * oi.quantity'),
          'soldListValue',
        )
        .addSelect(sumWhen(PENDING_CONDITION, 'oi.subtotal'), 'pendingRevenue')
        .addSelect(sumWhen(PENDING_CONDITION, 'oi.quantity'), 'unitsReserved')
        .addSelect(
          sumWhen(PENDING_CONDITION, 'i.price * oi.quantity'),
          'pendingListValue',
        )
        .from('order_items', 'oi')
        .innerJoin('items', 'i', 'i.id = oi."itemId"')
        .innerJoin('orders', 'o', 'o.id = oi."orderId"')
        .where('i."organizationId" = :organizationId', { organizationId })
        .andWhere('o."organizationId" = :organizationId', { organizationId })
        .andWhere(donorFilter, { ids })
        .groupBy('i."donorId"')
        .getRawMany(),
    ]);

    const stockById = new Map(stockRows.map((r) => [Number(r.donorId), r]));
    const salesById = new Map(salesRows.map((r) => [Number(r.donorId), r]));
    const num = (value: unknown) => Number(value) || 0;

    return new Map(
      donors.map((donor) => {
        const stock = stockById.get(donor.id);
        const sales = salesById.get(donor.id);
        return [
          donor.id,
          calculateDonorEconomics({
            purchasePrice: num(donor.purchasePrice),
            deliveryCost: num(donor.deliveryCost),
            dismantlingCost: num(donor.dismantlingCost),
            otherCosts: num(donor.otherCosts),
            scrapIncome: num(donor.scrapIncome),
            soldRevenue: num(sales?.soldRevenue),
            // Возвраты и списания появятся вместе со своими модулями (Phase 4–5).
            refunds: 0,
            pendingRevenue: num(sales?.pendingRevenue),
            stockValue: num(stock?.stockValue),
            soldListValue: num(sales?.soldListValue),
            pendingListValue: num(sales?.pendingListValue),
            writtenOffListValue: 0,
            partsCount: num(stock?.partsCount),
            unitsInStock: num(stock?.unitsInStock),
            unitsSold: num(sales?.unitsSold),
            unitsReserved: num(sales?.unitsReserved),
            unitsWrittenOff: 0,
          }),
        ];
      }),
    );
  }

  private async loadPartSales(
    organizationId: string,
    itemIds: number[],
  ): Promise<Map<number, PartSales>> {
    if (itemIds.length === 0) return new Map();
    const rows = await this.dataSource
      .createQueryBuilder()
      .select('oi."itemId"', 'itemId')
      .addSelect(sumWhen(SOLD_CONDITION, 'oi.quantity'), 'soldQuantity')
      .addSelect(sumWhen(SOLD_CONDITION, 'oi.subtotal'), 'soldRevenue')
      .addSelect(sumWhen(PENDING_CONDITION, 'oi.quantity'), 'pendingQuantity')
      .from('order_items', 'oi')
      .innerJoin('orders', 'o', 'o.id = oi."orderId"')
      .where('o."organizationId" = :organizationId', { organizationId })
      .andWhere('oi."itemId" IN (:...itemIds)', { itemIds })
      .groupBy('oi."itemId"')
      .getRawMany();

    return new Map(
      rows.map((r) => [
        Number(r.itemId),
        {
          soldQuantity: Number(r.soldQuantity) || 0,
          soldRevenue: Number(r.soldRevenue) || 0,
          pendingQuantity: Number(r.pendingQuantity) || 0,
        },
      ]),
    );
  }
}
