import { BadRequestException } from '@nestjs/common';
import { DonorStatus } from './entities/donor-vehicle.entity';
import {
  businessToday,
  parseDonorStatus,
  planStatusChange,
} from './donor-status';

const TODAY = '2026-10-06';
const donor = (
  status: DonorStatus,
  dismantlingStartDate: string | null = null,
  dismantlingEndDate: string | null = null,
) => ({ status, dismantlingStartDate, dismantlingEndDate });

describe('planStatusChange', () => {
  it('ставит дату начала при первом входе в разбор', () => {
    expect(
      planStatusChange(
        donor(DonorStatus.WAITING_FOR_DISMANTLING),
        DonorStatus.DISMANTLING,
        TODAY,
      ),
    ).toEqual({
      status: DonorStatus.DISMANTLING,
      dismantlingStartDate: TODAY,
      dismantlingEndDate: null,
    });
  });

  it('не перезаписывает уже известную дату начала', () => {
    const patch = planStatusChange(
      donor(DonorStatus.PARTIALLY_DISMANTLED, '2026-09-01'),
      DonorStatus.DISMANTLING,
      TODAY,
    );
    expect(patch).not.toHaveProperty('dismantlingStartDate');
  });

  it('ставит дату окончания при полном разборе', () => {
    expect(
      planStatusChange(
        donor(DonorStatus.DISMANTLING, '2026-09-01'),
        DonorStatus.FULLY_DISMANTLED,
        TODAY,
      ),
    ).toEqual({
      status: DonorStatus.FULLY_DISMANTLED,
      dismantlingEndDate: TODAY,
    });
  });

  it('возврат в разбор снимает дату окончания', () => {
    expect(
      planStatusChange(
        donor(DonorStatus.FULLY_DISMANTLED, '2026-09-01', '2026-09-20'),
        DonorStatus.DISMANTLING,
        TODAY,
      ),
    ).toEqual({ status: DonorStatus.DISMANTLING, dismantlingEndDate: null });
  });

  it('архив без разбора (продан целиком) не придумывает даты', () => {
    expect(
      planStatusChange(
        donor(DonorStatus.PURCHASED),
        DonorStatus.ARCHIVED,
        TODAY,
      ),
    ).toEqual({ status: DonorStatus.ARCHIVED });
  });

  it('архив после частичного разбора закрывает разбор', () => {
    expect(
      planStatusChange(
        donor(DonorStatus.PARTIALLY_DISMANTLED, '2026-09-01'),
        DonorStatus.ARCHIVED,
        TODAY,
      ),
    ).toEqual({ status: DonorStatus.ARCHIVED, dismantlingEndDate: TODAY });
  });

  it.each([
    [DonorStatus.PURCHASED, DonorStatus.FULLY_DISMANTLED],
    [DonorStatus.PURCHASED, DonorStatus.PARTIALLY_DISMANTLED],
    [DonorStatus.DISMANTLING, DonorStatus.PURCHASED],
    [DonorStatus.FULLY_DISMANTLED, DonorStatus.WAITING_FOR_DISMANTLING],
    [DonorStatus.ARCHIVED, DonorStatus.DISMANTLING],
  ])('запрещает %s → %s', (from, to) => {
    expect(() => planStatusChange(donor(from), to, TODAY)).toThrow(
      BadRequestException,
    );
  });

  it('тот же статус — ничего не меняет', () => {
    expect(
      planStatusChange(
        donor(DonorStatus.DISMANTLING),
        DonorStatus.DISMANTLING,
        TODAY,
      ),
    ).toEqual({});
  });
});

describe('parseDonorStatus', () => {
  it('понимает новые и старые значения', () => {
    expect(parseDonorStatus('partially_dismantled')).toBe(
      DonorStatus.PARTIALLY_DISMANTLED,
    );
    expect(parseDonorStatus('awaiting')).toBe(
      DonorStatus.WAITING_FOR_DISMANTLING,
    );
    expect(parseDonorStatus('dismantled')).toBe(DonorStatus.FULLY_DISMANTLED);
    expect(parseDonorStatus('closed')).toBe(DonorStatus.ARCHIVED);
    expect(parseDonorStatus(undefined)).toBeUndefined();
    expect(parseDonorStatus('')).toBeUndefined();
  });

  it('отклоняет неизвестные', () => {
    expect(() => parseDonorStatus('sold')).toThrow(BadRequestException);
    expect(() => parseDonorStatus(5)).toThrow(BadRequestException);
  });
});

describe('businessToday', () => {
  it('считает дату по часовому поясу бизнеса, а не UTC сервера', () => {
    // 2026-10-06 20:30 UTC = 2026-10-07 01:30 в Алматы (UTC+5)
    expect(businessToday(new Date('2026-10-06T20:30:00Z'))).toBe('2026-10-07');
  });
});
