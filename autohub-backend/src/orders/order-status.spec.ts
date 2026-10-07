import { BadRequestException } from '@nestjs/common';
import {
  assertOrderTransition,
  nextHold,
  planStockChange,
} from './order-status';

describe('статусы заказа', () => {
  it('пропускает текущий экран: ожидание → бронь → готов → завершён', () => {
    expect(() => assertOrderTransition('pending', 'reserved')).not.toThrow();
    expect(() => assertOrderTransition('reserved', 'ready')).not.toThrow();
    expect(() => assertOrderTransition('ready', 'completed')).not.toThrow();
  });

  it('не даёт открыть отменённый заказ заново', () => {
    expect(() => assertOrderTransition('cancelled', 'pending')).toThrow(
      BadRequestException,
    );
  });
});

describe('сквозной склад продажи', () => {
  it('резерв не списывает остаток, завершение списывает, отмена возвращает', () => {
    expect(planStockChange('reserve', 'cancelled')).toBe('release');
    expect(planStockChange('reserve', 'completed')).toBe('convert');
    expect(nextHold('reserve', 'completed')).toBe('sale');
    expect(planStockChange('sale', 'returned')).toBe('keep');
    expect(planStockChange('sale', 'cancelled')).toBe('restock');
    expect(nextHold('sale', 'cancelled')).toBe('none');
    expect(planStockChange('none', 'cancelled')).toBe('keep');
  });
});
