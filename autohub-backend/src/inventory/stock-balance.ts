import { BadRequestException } from '@nestjs/common';

export interface StockLevels {
  quantity: number;
  reserved: number;
}

export interface StockDeltas {
  quantityDelta: number;
  reservedDelta: number;
}

/** Следующий остаток. Не уходит в минус, резерв не больше остатка. */
export function nextStock(
  current: StockLevels,
  deltas: StockDeltas,
): StockLevels {
  const quantity = current.quantity + deltas.quantityDelta;
  const reserved = current.reserved + deltas.reservedDelta;
  if (
    !Number.isInteger(quantity) ||
    !Number.isInteger(reserved) ||
    quantity < 0 ||
    reserved < 0 ||
    reserved > quantity
  ) {
    const available = current.quantity - current.reserved;
    throw new BadRequestException(
      `Недостаточно на складе: доступно ${available}`,
    );
  }
  return { quantity, reserved };
}
