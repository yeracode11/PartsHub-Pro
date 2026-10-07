import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, Repository } from 'typeorm';
import { Item } from '../items/entities/item.entity';
import { Listing } from './entities/listing.entity';
import {
  ListingChannel,
  ListingSnapshot,
  ListingStatus,
  MarketplaceAdapter,
} from './marketplace-adapter';
import { CatalogAdapter, UnconfiguredChannelAdapter } from './adapters';

const TICK_MS = 60_000;
const CHANNELS = new Set<string>(Object.values(ListingChannel));

@Injectable()
export class ListingsService implements OnModuleInit, OnModuleDestroy {
  private readonly adapters = new Map<ListingChannel, MarketplaceAdapter>();
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @InjectRepository(Listing)
    private readonly listingRepository: Repository<Listing>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
  ) {
    const catalog = new CatalogAdapter();
    this.adapters.set(catalog.channel, catalog);
    for (const channel of [
      ListingChannel.KOLESA,
      ListingChannel.OLX,
      ListingChannel.WHATSAPP,
      ListingChannel.TELEGRAM,
    ]) {
      this.adapters.set(channel, new UnconfiguredChannelAdapter(channel));
    }
  }

  onModuleInit() {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => {
      void this.pushDue().catch(() => undefined);
    }, TICK_MS);
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  list(organizationId: string, itemId?: number) {
    return this.listingRepository.find({
      where: {
        organizationId,
        ...(itemId ? { itemId } : {}),
      },
      order: { channel: 'ASC' },
    });
  }

  async create(
    organizationId: string,
    raw: {
      itemId?: unknown;
      channel?: unknown;
      title?: unknown;
      price?: unknown;
      quantity?: unknown;
      publish?: unknown;
    },
  ) {
    const itemId = Number(raw.itemId);
    const channel = String(raw.channel || '');
    if (!Number.isInteger(itemId) || itemId <= 0) {
      throw new BadRequestException('Укажите товар');
    }
    if (!CHANNELS.has(channel)) {
      throw new BadRequestException('Неизвестный канал');
    }
    const item = await this.requireItem(itemId, organizationId);
    const existing = await this.listingRepository.findOne({
      where: { organizationId, itemId, channel: channel as ListingChannel },
    });
    if (existing && existing.status !== ListingStatus.ARCHIVED) {
      throw new ConflictException('Объявление на этом канале уже есть');
    }
    const draft = this.fromItem(item, channel as ListingChannel, raw);
    const saved = existing
      ? await this.listingRepository.save(Object.assign(existing, draft, { status: ListingStatus.DRAFT, lastSyncError: null }))
      : await this.listingRepository.save(this.listingRepository.create(draft));
    if (raw.publish === true || channel === ListingChannel.CATALOG) {
      return this.publish(saved.id, organizationId);
    }
    return saved;
  }

  async publish(id: string, organizationId: string) {
    const listing = await this.require(id, organizationId);
    const item = await this.requireItem(listing.itemId, organizationId);
    this.copyStock(listing, item);
    const result = await this.adapter(listing.channel).createListing(this.snapshot(listing));
    return this.applyResult(listing, item, result);
  }

  async pause(id: string, organizationId: string) {
    const listing = await this.require(id, organizationId);
    listing.status = ListingStatus.PAUSED;
    listing.nextAttemptAt = null;
    await this.listingRepository.save(listing);
    if (listing.channel === ListingChannel.CATALOG) {
      await this.itemRepository.update(
        { id: listing.itemId, organizationId },
        { syncedToB2C: false },
      );
    }
    return listing;
  }

  async remove(id: string, organizationId: string) {
    const listing = await this.require(id, organizationId);
    const item = await this.requireItem(listing.itemId, organizationId);
    const result = await this.adapter(listing.channel).deleteListing(this.snapshot(listing));
    listing.status = result.status;
    listing.externalId = result.externalId;
    listing.lastSyncError = result.error;
    listing.nextAttemptAt = null;
    await this.listingRepository.save(listing);
    if (listing.channel === ListingChannel.CATALOG) {
      await this.itemRepository.update(
        { id: item.id, organizationId },
        { syncedToB2C: false },
      );
    }
    return listing;
  }

  /** После движения склада: площадка сама не читает остаток. */
  async markStale(manager: EntityManager, organizationId: string, itemId: number) {
    await manager.query(
      `UPDATE listings
       SET status = $3, "nextAttemptAt" = now()
       WHERE "organizationId" = $1
         AND "itemId" = $2
         AND status IN ($4, $3)`,
      [
        organizationId,
        itemId,
        ListingStatus.NEEDS_SYNC,
        ListingStatus.PUBLISHED,
      ],
    );
  }

  async pushDue() {
    const due = await this.listingRepository
      .createQueryBuilder('listing')
      .where('listing.status = :status', { status: ListingStatus.NEEDS_SYNC })
      .andWhere('(listing.nextAttemptAt IS NULL OR listing.nextAttemptAt <= now())')
      .orderBy('listing.organizationId', 'ASC')
      .take(100)
      .getMany();
    const byOrg = new Map<string, Listing[]>();
    for (const row of due) {
      const list = byOrg.get(row.organizationId) ?? [];
      list.push(row);
      byOrg.set(row.organizationId, list);
    }
    for (const [organizationId, rows] of byOrg) {
      for (const listing of rows) {
        const item = await this.itemRepository.findOne({
          where: { id: listing.itemId, organizationId },
        });
        if (!item) continue;
        this.copyStock(listing, item);
        const result = await this.adapter(listing.channel).updateStock(this.snapshot(listing));
        await this.applyResult(listing, item, result);
      }
    }
  }

  private async applyResult(
    listing: Listing,
    item: Item,
    result: { status: ListingStatus; externalId: string | null; error: string | null; retryInMs: number | null },
  ) {
    listing.status = result.status;
    listing.externalId = result.externalId;
    listing.lastSyncError = result.error;
    listing.nextAttemptAt = result.retryInMs ? new Date(Date.now() + result.retryInMs) : null;
    if (result.status === ListingStatus.PUBLISHED && !listing.publishedAt) {
      listing.publishedAt = new Date();
    }
    const saved = await this.listingRepository.save(listing);
    if (listing.channel === ListingChannel.CATALOG) {
      await this.itemRepository.update(
        { id: item.id, organizationId: item.organizationId },
        { syncedToB2C: result.status === ListingStatus.PUBLISHED },
      );
    }
    return saved;
  }

  private fromItem(
    item: Item,
    channel: ListingChannel,
    raw: { title?: unknown; price?: unknown; quantity?: unknown },
  ): Partial<Listing> {
    const available = Math.max(0, Number(item.quantity) - Number(item.reservedQuantity ?? 0));
    const quantity = raw.quantity === undefined ? available : Number(raw.quantity);
    if (!Number.isInteger(quantity) || quantity < 0 || quantity > available) {
      throw new BadRequestException('Количество больше доступного');
    }
    const price = raw.price === undefined ? Number(item.price) : Number(raw.price);
    if (!Number.isFinite(price) || price < 0) {
      throw new BadRequestException('Неверная цена объявления');
    }
    const title =
      typeof raw.title === 'string' && raw.title.trim()
        ? raw.title.trim().slice(0, 200)
        : item.name.slice(0, 200);
    return {
      organizationId: item.organizationId,
      itemId: item.id,
      channel,
      title,
      description: item.description,
      photos: Array.isArray(item.images) ? item.images : [],
      price: price.toFixed(2),
      quantity,
      status: ListingStatus.DRAFT,
      externalId: null,
      publishedAt: null,
      nextAttemptAt: null,
      lastSyncError: null,
    };
  }

  private copyStock(listing: Listing, item: Item) {
    listing.quantity = Math.max(
      0,
      Number(item.quantity) - Number(item.reservedQuantity ?? 0),
    );
    listing.price = Number(item.price).toFixed(2);
    listing.photos = Array.isArray(item.images) ? item.images : listing.photos;
  }

  private snapshot(listing: Listing): ListingSnapshot {
    return {
      id: listing.id,
      organizationId: listing.organizationId,
      itemId: listing.itemId,
      channel: listing.channel,
      title: listing.title,
      description: listing.description,
      photos: listing.photos ?? [],
      price: String(listing.price),
      quantity: listing.quantity,
      externalId: listing.externalId,
    };
  }

  private adapter(channel: ListingChannel) {
    const found = this.adapters.get(channel);
    if (!found) throw new BadRequestException('Неизвестный канал');
    return found;
  }

  private async require(id: string, organizationId: string) {
    const listing = await this.listingRepository.findOne({ where: { id, organizationId } });
    if (!listing) throw new NotFoundException('Объявление не найдено');
    return listing;
  }

  private async requireItem(itemId: number, organizationId: string) {
    const item = await this.itemRepository.findOne({ where: { id: itemId, organizationId } });
    if (!item) throw new NotFoundException('Товар не найден');
    return item;
  }
}
