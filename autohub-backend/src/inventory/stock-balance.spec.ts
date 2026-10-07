import { BadRequestException } from '@nestjs/common';
import { nextStock } from './stock-balance';

describe('nextStock', () => {
  it('списывает продажу, не трогая резерв', () => {
    expect(
      nextStock(
        { quantity: 5, reserved: 1 },
        { quantityDelta: -2, reservedDelta: 0 },
      ),
    ).toEqual({ quantity: 3, reserved: 1 });
  });

  it('не даёт продать зарезервированное', () => {
    expect(() =>
      nextStock(
        { quantity: 5, reserved: 4 },
        { quantityDelta: -2, reservedDelta: 0 },
      ),
    ).toThrow(BadRequestException);
  });

  it('не уходит в минус и не резервирует больше остатка', () => {
    expect(() =>
      nextStock(
        { quantity: 1, reserved: 0 },
        { quantityDelta: -2, reservedDelta: 0 },
      ),
    ).toThrow(BadRequestException);
    expect(() =>
      nextStock(
        { quantity: 2, reserved: 0 },
        { quantityDelta: 0, reservedDelta: 3 },
      ),
    ).toThrow(BadRequestException);
  });
});
