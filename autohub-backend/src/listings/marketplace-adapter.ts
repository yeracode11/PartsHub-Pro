export enum ListingChannel {
  CATALOG = 'catalog',
  KOLESA = 'kolesa',
  OLX = 'olx',
  WHATSAPP = 'whatsapp',
  TELEGRAM = 'telegram',
}

export enum ListingStatus {
  DRAFT = 'draft',
  PUBLISHED = 'published',
  PAUSED = 'paused',
  NEEDS_SYNC = 'needs_sync',
  ARCHIVED = 'archived',
}

export interface ListingSnapshot {
  id: string;
  organizationId: string;
  itemId: number;
  channel: ListingChannel;
  title: string;
  description: string | null;
  photos: string[];
  price: string;
  quantity: number;
  externalId: string | null;
}

export interface ListingPushResult {
  status: ListingStatus;
  externalId: string | null;
  error: string | null;
  /** Когда имеет смысл повторить. null — сразу считается доставленным. */
  retryInMs: number | null;
}

export interface MarketplaceAdapter {
  readonly channel: ListingChannel;
  createListing(listing: ListingSnapshot): Promise<ListingPushResult>;
  updateListing(listing: ListingSnapshot): Promise<ListingPushResult>;
  deleteListing(listing: ListingSnapshot): Promise<ListingPushResult>;
  updateStock(listing: ListingSnapshot): Promise<ListingPushResult>;
  updatePrice(listing: ListingSnapshot): Promise<ListingPushResult>;
  importListing(listing: ListingSnapshot): Promise<ListingPushResult>;
}
