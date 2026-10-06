import { BadRequestException } from '@nestjs/common';
import { Item, ItemStatus } from './entities/item.entity';
import { CrossReferenceType } from './entities/part-cross-reference.entity';
import { normalizeOem } from './oem';

export const MAX_ITEM_RELATIONS = 50;
const MAX_VIDEOS = 10;
const MAX_PAGE_SIZE = 100;
const MIN_YEAR = 1950;

/** Поля, которые клиент может менять через общий CRUD товара. */
const EDITABLE_FIELDS = [
  'name',
  'sku',
  'category',
  'price',
  'quantity',
  'condition',
  'description',
  'imageUrl',
  'images',
  'warehouseCell',
  'warehouseId',
  'synced',
  'syncedToB2C',
] as const;

const CODE_FIELDS = ['internalCode', 'barcode', 'oem', 'brand'] as const;

export interface CrossReferenceInput {
  oem: string;
  oemNormalized: string;
  brand: string | null;
  type: CrossReferenceType;
}

export interface CompatibilityInput {
  make: string;
  model: string;
  generation: string | null;
  yearFrom: number | null;
  yearTo: number | null;
  body: string | null;
  engine: string | null;
  transmission: string | null;
}

export interface ItemCatalogInput {
  fields: Partial<Item>;
  /** undefined — не трогать, [] — очистить. */
  crossReferences?: CrossReferenceInput[];
  compatibility?: CompatibilityInput[];
}

export interface ItemListQuery {
  search?: string;
  code?: string;
  sku?: string;
  category?: string;
  categories?: string[];
  condition?: string;
  status?: ItemStatus;
  warehouseId?: string;
  minPrice?: number;
  maxPrice?: number;
  minQuantity?: number;
  maxQuantity?: number;
  inStock?: boolean;
  syncedToB2C?: boolean;
  /** Без limit ответ — массив, как у старых клиентов. */
  limit?: number;
  offset: number;
}

function optionalText(value: unknown, field: string, max: number) {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== 'string') {
    throw new BadRequestException(`Поле «${field}» должно быть строкой`);
  }
  const text = value.trim();
  if (text.length > max) {
    throw new BadRequestException(`Поле «${field}» длиннее ${max} символов`);
  }
  return text || null;
}

function requiredText(value: unknown, field: string, max: number): string {
  const text = optionalText(value, field, max);
  if (!text) throw new BadRequestException(`Укажите «${field}»`);
  return text;
}

function optionalYear(value: unknown, field: string): number | null {
  if (value === undefined || value === null || value === '') return null;
  const year = Number(value);
  const maxYear = new Date().getFullYear() + 1;
  if (!Number.isInteger(year) || year < MIN_YEAR || year > maxYear) {
    throw new BadRequestException(
      `«${field}»: год от ${MIN_YEAR} до ${maxYear}`,
    );
  }
  return year;
}

function relationList(value: unknown, field: string): unknown[] | undefined {
  if (value === undefined) return undefined;
  if (value === null) return [];
  if (!Array.isArray(value)) {
    throw new BadRequestException(`«${field}» должно быть списком`);
  }
  if (value.length > MAX_ITEM_RELATIONS) {
    throw new BadRequestException(
      `«${field}»: не больше ${MAX_ITEM_RELATIONS} строк`,
    );
  }
  return value;
}

function asRecord(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new BadRequestException(`«${field}»: неверный формат строки`);
  }
  return value as Record<string, unknown>;
}

function parseCrossReferences(value: unknown) {
  const list = relationList(value, 'Аналоги');
  if (!list) return undefined;
  const byNumber = new Map<string, CrossReferenceInput>();
  for (const raw of list) {
    const row = asRecord(raw, 'Аналоги');
    const oem = requiredText(row.oem, 'Номер аналога', 100);
    const oemNormalized = normalizeOem(oem);
    if (!oemNormalized) {
      throw new BadRequestException(`Номер аналога «${oem}» без цифр и букв`);
    }
    const type = row.type ?? CrossReferenceType.ALTERNATIVE;
    if (
      !Object.values(CrossReferenceType).includes(type as CrossReferenceType)
    ) {
      throw new BadRequestException(
        `Неизвестный тип аналога «${JSON.stringify(type)}»`,
      );
    }
    byNumber.set(oemNormalized, {
      oem,
      oemNormalized,
      brand: optionalText(row.brand, 'Бренд аналога', 100) ?? null,
      type: type as CrossReferenceType,
    });
  }
  return [...byNumber.values()];
}

function parseCompatibility(value: unknown) {
  const list = relationList(value, 'Применимость');
  if (!list) return undefined;
  return list.map((raw) => {
    const row = asRecord(raw, 'Применимость');
    const fit: CompatibilityInput = {
      make: requiredText(row.make, 'Марка', 50),
      model: requiredText(row.model, 'Модель', 80),
      generation: optionalText(row.generation, 'Поколение', 50) ?? null,
      yearFrom: optionalYear(row.yearFrom, 'Год с'),
      yearTo: optionalYear(row.yearTo, 'Год по'),
      body: optionalText(row.body, 'Кузов', 50) ?? null,
      engine: optionalText(row.engine, 'Двигатель', 80) ?? null,
      transmission: optionalText(row.transmission, 'КПП', 20) ?? null,
    };
    if (fit.yearFrom && fit.yearTo && fit.yearFrom > fit.yearTo) {
      throw new BadRequestException('«Год с» позже, чем «Год по»');
    }
    return fit;
  });
}

function parseVideos(value: unknown): string[] | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (!Array.isArray(value) || value.length > MAX_VIDEOS) {
    throw new BadRequestException(`Видео: список до ${MAX_VIDEOS} ссылок`);
  }
  return value.map((url) => {
    const text = optionalText(url, 'Видео', 500);
    if (!text || !/^https?:\/\/\S+$/i.test(text)) {
      throw new BadRequestException('Видео: нужна ссылка http(s)');
    }
    return text;
  });
}

function parseMoney(value: unknown, field: string): string | null {
  if (value === null || value === '') return null;
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0 || amount > 1e10) {
    throw new BadRequestException(`«${field}»: неверная сумма`);
  }
  return amount.toFixed(2);
}

/**
 * Разбор тела create/update товара: только известные поля,
 * OEM нормализуется, закупочную цену меняют только финансовые роли.
 */
export function parseItemCatalogInput(
  data: unknown,
  options: { canEditCost: boolean },
): ItemCatalogInput {
  const body = (data && typeof data === 'object' ? data : {}) as Record<
    string,
    unknown
  >;
  const fields: Record<string, unknown> = {};

  for (const key of EDITABLE_FIELDS) {
    if (key in body) fields[key] = body[key];
  }
  for (const key of CODE_FIELDS) {
    const value = optionalText(body[key], key, 100);
    if (value !== undefined) fields[key] = value;
  }
  if ('oem' in fields) fields.oemNormalized = normalizeOem(fields.oem);

  if (body.status !== undefined) {
    if (!Object.values(ItemStatus).includes(body.status as ItemStatus)) {
      throw new BadRequestException(
        `Неизвестный статус «${JSON.stringify(body.status)}»`,
      );
    }
    fields.status = body.status;
  }
  const videos = parseVideos(body.videos);
  if (videos !== undefined) fields.videos = videos;
  if (options.canEditCost && body.purchaseCost !== undefined) {
    fields.purchaseCost = parseMoney(body.purchaseCost, 'Закупочная цена');
  }

  return {
    fields: fields as Partial<Item>,
    crossReferences: parseCrossReferences(body.crossReferences),
    compatibility: parseCompatibility(body.compatibility),
  };
}

const text = (value: unknown) =>
  typeof value === 'string' && value.trim() ? value.trim() : undefined;

const num = (value: unknown) => {
  if (value === undefined || value === null || value === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
};

/** Query-параметры приходят строками: «false» должно значить false. */
const bool = (value: unknown) => {
  if (value === true || value === 'true' || value === '1') return true;
  if (value === false || value === 'false' || value === '0') return false;
  return undefined;
};

export function parseItemListQuery(
  query: Record<string, unknown> = {},
): ItemListQuery {
  const categories = Array.isArray(query.categories)
    ? query.categories.map(text).filter((c): c is string => !!c)
    : text(query.categories)
        ?.split(',')
        .map((c) => c.trim())
        .filter(Boolean);
  const status = text(query.status) as ItemStatus | undefined;
  const limit = num(query.limit);

  return {
    search: text(query.search)?.slice(0, 100),
    code: text(query.code)?.slice(0, 100),
    sku: text(query.sku),
    category: text(query.category),
    categories: categories?.length ? categories : undefined,
    condition: text(query.condition),
    status:
      status && Object.values(ItemStatus).includes(status) ? status : undefined,
    warehouseId: text(query.warehouseId),
    minPrice: num(query.minPrice),
    maxPrice: num(query.maxPrice),
    minQuantity: num(query.minQuantity),
    maxQuantity: num(query.maxQuantity),
    inStock: bool(query.inStock),
    syncedToB2C: bool(query.syncedToB2C),
    limit:
      limit === undefined
        ? undefined
        : Math.min(Math.max(Math.trunc(limit), 1), MAX_PAGE_SIZE),
    offset: Math.max(Math.trunc(num(query.offset) ?? 0), 0),
  };
}

/** Пользовательский текст в LIKE: % и _ ищутся буквально. */
export const escapeLike = (value: string) => value.replace(/[\\%_]/g, '\\$&');
