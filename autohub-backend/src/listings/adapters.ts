import { ListingChannel, ListingPushResult, ListingSnapshot, ListingStatus, MarketplaceAdapter } from './marketplace-adapter';

/** Публичный каталог PartsHub. Внешнего HTTP нет: витрина читает нашу базу. */
export class CatalogAdapter implements MarketplaceAdapter {
  readonly channel = ListingChannel.CATALOG;

  createListing(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.ok(listing));
  }

  updateListing(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.ok(listing));
  }

  deleteListing(): Promise<ListingPushResult> {
    return Promise.resolve({
      status: ListingStatus.ARCHIVED,
      externalId: null,
      error: null,
      retryInMs: null,
    });
  }

  updateStock(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.ok(listing));
  }

  updatePrice(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.ok(listing));
  }

  importListing(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.ok(listing));
  }

  private ok(listing: ListingSnapshot): ListingPushResult {
    return {
      status: ListingStatus.PUBLISHED,
      externalId: listing.externalId ?? `catalog:${listing.itemId}`,
      error: null,
      retryInMs: null,
    };
  }
}

/**
 * Площадка ещё без ключей. Объявление остаётся в очереди и не уходит в интернет.
 */
export class UnconfiguredChannelAdapter implements MarketplaceAdapter {
  constructor(readonly channel: ListingChannel) {}

  createListing(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.waiting(listing));
  }

  updateListing(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.waiting(listing));
  }

  deleteListing(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve({
      status: ListingStatus.ARCHIVED,
      externalId: listing.externalId,
      error: null,
      retryInMs: null,
    });
  }

  updateStock(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.waiting(listing));
  }

  updatePrice(listing: ListingSnapshot): Promise<ListingPushResult> {
    return Promise.resolve(this.waiting(listing));
  }

  importListing(): Promise<ListingPushResult> {
    return Promise.reject(new Error('Импорт с этой площадки ещё не подключён'));
  }

  private waiting(listing: ListingSnapshot): ListingPushResult {
    return {
      status: ListingStatus.NEEDS_SYNC,
      externalId: listing.externalId,
      error: 'Канал не подключён',
      retryInMs: 24 * 60 * 60 * 1000,
    };
  }
}
