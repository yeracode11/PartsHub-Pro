import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { DonorStatus, DonorVehicle } from './entities/donor-vehicle.entity';
import { Item } from '../items/entities/item.entity';
import { AddDonorPartsDto, CreateDonorDto, UpdateDonorDto } from './dto/donor.dto';
import {
  allocateDonorCost,
  calculateDonorEconomics,
  DonorEconomics,
} from './donor-economics';

/** Деньги по заказу считаем полученными, когда заказ завершён или оплачен. */
const SOLD_CONDITION = `o.status <> 'cancelled' AND (o.status = 'completed' OR o."paymentStatus" = 'paid')`;
const PENDING_CONDITION = `o.status <> 'cancelled' AND NOT (o.status = 'completed' OR o."paymentStatus" = 'paid')`;

const FINANCE_FIELDS = ['purchasePrice', 'extraCosts', 'scrapIncome'] as const;

type DonorWithEconomics = DonorVehicle & { economics?: DonorEconomics };

export const MAX_PHOTOS = 20;

interface PartSales {
  soldQuantity: number;
  soldRevenue: number;
  pendingQuantity: number;
}

const NO_SALES: PartSales = { soldQuantity: 0, soldRevenue: 0, pendingQuantity: 0 };

@Injectable()
export class DonorsService {
  constructor(
    @InjectRepository(DonorVehicle)
    private readonly donorRepository: Repository<DonorVehicle>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    private readonly dataSource: DataSource,
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

    const economics = await this.loadEconomics(
      organizationId,
      donors,
    );
    return donors.map((donor) =>
      this.present(donor, economics.get(donor.id)!, options.includeFinance),
    );
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

  async create(organizationId: string, dto: CreateDonorDto) {
    const donor = this.donorRepository.create({
      ...this.normalize(dto),
      organizationId,
      status: DonorStatus.AWAITING,
    });
    const saved = await this.donorRepository.save(donor);
    return this.findOne(saved.id, organizationId, true);
  }

  async update(id: number, organizationId: string, dto: UpdateDonorDto) {
    await this.getDonor(id, organizationId);
    const data = this.normalize(dto);
    if (Object.keys(data).length > 0) {
      await this.donorRepository.update({ id, organizationId }, data);
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
        'С донора уже сняты детали. Удалить нельзя — закройте учёт (статус «Закрыт»).',
      );
    }
    await this.donorRepository.delete({ id, organizationId });
    return { success: true };
  }

  /** Снять детали с донора: каждая деталь становится товаром склада с привязкой к машине. */
  async addParts(id: number, organizationId: string, dto: AddDonorPartsDto) {
    const donor = await this.getDonor(id, organizationId);
    if (donor.status === DonorStatus.CLOSED) {
      throw new BadRequestException('Учёт по донору закрыт');
    }

    const origin = this.describeOrigin(donor);
    const created = await this.dataSource.transaction(async (manager) => {
      const items = dto.parts.map((part) =>
        manager.create(Item, {
          organizationId,
          donorId: donor.id,
          name: part.name.trim(),
          category: part.category?.trim() || null,
          price: part.price,
          quantity: part.quantity ?? 1,
          condition: part.condition || 'used',
          warehouseCell: part.warehouseCell?.trim() || null,
          sku: part.sku?.trim() || null,
          description: part.description?.trim()
            ? `${part.description.trim()}\n${origin}`
            : origin,
          syncedToB2C: true,
        }),
      );
      const saved = await manager.save(Item, items);

      if (donor.status === DonorStatus.AWAITING) {
        await manager.update(
          DonorVehicle,
          { id: donor.id, organizationId },
          { status: DonorStatus.DISMANTLING },
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

  private normalize(dto: CreateDonorDto | UpdateDonorDto): Partial<DonorVehicle> {
    const data: Partial<DonorVehicle> = { ...(dto as any) };
    if (dto.brand !== undefined) data.brand = dto.brand.trim();
    if (dto.model !== undefined) data.model = dto.model.trim();
    if (dto.vin !== undefined) {
      const vin = dto.vin.replace(/\s+/g, '').toUpperCase();
      data.vin = vin.length ? vin : null;
    }
    if (dto.purchaseDate !== undefined) {
      data.purchaseDate = dto.purchaseDate ? new Date(dto.purchaseDate) : null;
    }
    return data;
  }

  private describeOrigin(donor: DonorVehicle): string {
    const car = [donor.brand, donor.model, donor.year].filter(Boolean).join(' ');
    const details = [
      donor.engine ? `двигатель ${donor.engine}` : null,
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
    const result: DonorWithEconomics = { ...donor };
    if (includeFinance) {
      result.economics = economics;
    } else {
      for (const field of FINANCE_FIELDS) delete (result as any)[field];
      (result as any).stock = {
        partsCount: economics.partsCount,
        unitsInStock: economics.unitsInStock,
        unitsSold: economics.unitsSold,
      };
    }
    return result;
  }

  /** Экономика по списку доноров за три агрегирующих запроса, без N+1. */
  private async loadEconomics(
    organizationId: string,
    donors: DonorVehicle[],
  ): Promise<Map<number, DonorEconomics>> {
    const ids = donors.map((d) => d.id);

    const [stockRows, salesRows] = await Promise.all([
      this.itemRepository
        .createQueryBuilder('i')
        .select('i."donorId"', 'donorId')
        .addSelect('COUNT(*)', 'partsCount')
        .addSelect('COALESCE(SUM(i.quantity), 0)', 'unitsInStock')
        .addSelect('COALESCE(SUM(i.price * i.quantity), 0)', 'stockValue')
        .where('i."organizationId" = :organizationId', { organizationId })
        .andWhere('i."donorId" IN (:...ids)', { ids })
        .groupBy('i."donorId"')
        .getRawMany(),
      this.dataSource
        .createQueryBuilder()
        .select('i."donorId"', 'donorId')
        .addSelect(
          `COALESCE(SUM(CASE WHEN ${SOLD_CONDITION} THEN oi.subtotal ELSE 0 END), 0)`,
          'soldRevenue',
        )
        .addSelect(
          `COALESCE(SUM(CASE WHEN ${SOLD_CONDITION} THEN oi.quantity ELSE 0 END), 0)`,
          'unitsSold',
        )
        .addSelect(
          `COALESCE(SUM(CASE WHEN ${PENDING_CONDITION} THEN oi.subtotal ELSE 0 END), 0)`,
          'pendingRevenue',
        )
        .from('order_items', 'oi')
        .innerJoin('items', 'i', 'i.id = oi."itemId"')
        .innerJoin('orders', 'o', 'o.id = oi."orderId"')
        .where('i."organizationId" = :organizationId', { organizationId })
        .andWhere('o."organizationId" = :organizationId', { organizationId })
        .andWhere('i."donorId" IN (:...ids)', { ids })
        .groupBy('i."donorId"')
        .getRawMany(),
    ]);

    const stockById = new Map(stockRows.map((r) => [Number(r.donorId), r]));
    const salesById = new Map(salesRows.map((r) => [Number(r.donorId), r]));

    return new Map(
      donors.map((donor) => {
        const stock = stockById.get(donor.id);
        const sales = salesById.get(donor.id);
        return [
          donor.id,
          calculateDonorEconomics({
            purchasePrice: Number(donor.purchasePrice) || 0,
            extraCosts: Number(donor.extraCosts) || 0,
            scrapIncome: Number(donor.scrapIncome) || 0,
            soldRevenue: Number(sales?.soldRevenue) || 0,
            pendingRevenue: Number(sales?.pendingRevenue) || 0,
            stockValue: Number(stock?.stockValue) || 0,
            partsCount: Number(stock?.partsCount) || 0,
            unitsInStock: Number(stock?.unitsInStock) || 0,
            unitsSold: Number(sales?.unitsSold) || 0,
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
      .addSelect(
        `COALESCE(SUM(CASE WHEN ${SOLD_CONDITION} THEN oi.quantity ELSE 0 END), 0)`,
        'soldQuantity',
      )
      .addSelect(
        `COALESCE(SUM(CASE WHEN ${SOLD_CONDITION} THEN oi.subtotal ELSE 0 END), 0)`,
        'soldRevenue',
      )
      .addSelect(
        `COALESCE(SUM(CASE WHEN ${PENDING_CONDITION} THEN oi.quantity ELSE 0 END), 0)`,
        'pendingQuantity',
      )
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
