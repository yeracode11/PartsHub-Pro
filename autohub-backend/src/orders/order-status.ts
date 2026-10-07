import { BadRequestException } from '@nestjs/common';

/** Как заказ держит склад. none — B2C, остаток не трогали. */
export type StockHold = 'sale' | 'reserve' | 'none';

export const ORDER_STATUSES = [
  'draft',
  'cart',
  'pending',
  'reserved',
  'processing',
  'picking',
  'ready',
  'delivered',
  'completed',
  'cancelled',
  'returned',
] as const;

export type OrderStatus = (typeof ORDER_STATUSES)[number];

const LEGACY = new Set<string>(ORDER_STATUSES);

const FLOW = [
  'draft',
  'cart',
  'pending',
  'reserved',
  'processing',
  'picking',
  'ready',
  'delivered',
  'completed',
  'returned',
  'cancelled',
] as const;

/** Экран заказа ставит статус сразу, без промежуточных шагов. */
const TRANSITIONS: Record<string, readonly string[]> = {
  draft: FLOW,
  cart: FLOW,
  pending: FLOW,
  reserved: FLOW,
  processing: FLOW,
  picking: FLOW,
  ready: FLOW,
  delivered: FLOW,
  completed: FLOW,
  returned: ['completed', 'cancelled'],
  cancelled: [],
};

export function isOrderStatus(value: string): value is OrderStatus {
  return LEGACY.has(value);
}

export function assertOrderTransition(from: string, to: string) {
  if (from === to) return;
  if (!isOrderStatus(to)) {
    throw new BadRequestException('Неизвестный статус заказа');
  }
  const allowed = TRANSITIONS[from] ?? TRANSITIONS.pending;
  if (!allowed.includes(to)) {
    throw new BadRequestException('Такой переход статуса недоступен');
  }
}

/**
 * Что сделать с остатком при смене статуса без замены строк.
 * Отмена продажи возвращает товар. Резерв при сборке становится продажей.
 * Возврат сам по себе остаток не двигает — это отдельный документ.
 */
export function planStockChange(
  hold: StockHold,
  nextStatus: string,
): 'keep' | 'release' | 'convert' | 'restock' {
  if (hold === 'none') return 'keep';
  if (nextStatus === 'cancelled') {
    return hold === 'reserve' ? 'release' : 'restock';
  }
  if (
    hold === 'reserve' &&
    ['processing', 'picking', 'ready', 'delivered', 'completed'].includes(
      nextStatus,
    )
  ) {
    return 'convert';
  }
  return 'keep';
}

export function nextHold(current: StockHold, nextStatus: string): StockHold {
  const plan = planStockChange(current, nextStatus);
  if (plan === 'release' || plan === 'restock') return 'none';
  if (plan === 'convert') return 'sale';
  if (nextStatus === 'reserved' && current !== 'none') return 'reserve';
  return current;
}
