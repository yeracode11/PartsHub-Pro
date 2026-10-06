import { BadRequestException } from '@nestjs/common';
import { DonorStatus } from './entities/donor-vehicle.entity';

export const DONOR_STATUS_LABELS: Record<DonorStatus, string> = {
  [DonorStatus.PURCHASED]: 'Куплен',
  [DonorStatus.WAITING_FOR_DISMANTLING]: 'Ждёт разбора',
  [DonorStatus.DISMANTLING]: 'В разборе',
  [DonorStatus.PARTIALLY_DISMANTLED]: 'Разобран частично',
  [DonorStatus.FULLY_DISMANTLED]: 'Разобран полностью',
  [DonorStatus.ARCHIVED]: 'В архиве',
};

const TRANSITIONS: Record<DonorStatus, DonorStatus[]> = {
  [DonorStatus.PURCHASED]: [
    DonorStatus.WAITING_FOR_DISMANTLING,
    DonorStatus.DISMANTLING,
    DonorStatus.ARCHIVED,
  ],
  [DonorStatus.WAITING_FOR_DISMANTLING]: [
    DonorStatus.PURCHASED,
    DonorStatus.DISMANTLING,
    DonorStatus.ARCHIVED,
  ],
  [DonorStatus.DISMANTLING]: [
    DonorStatus.PARTIALLY_DISMANTLED,
    DonorStatus.FULLY_DISMANTLED,
    DonorStatus.ARCHIVED,
  ],
  [DonorStatus.PARTIALLY_DISMANTLED]: [
    DonorStatus.DISMANTLING,
    DonorStatus.FULLY_DISMANTLED,
    DonorStatus.ARCHIVED,
  ],
  [DonorStatus.FULLY_DISMANTLED]: [
    DonorStatus.DISMANTLING,
    DonorStatus.ARCHIVED,
  ],
  [DonorStatus.ARCHIVED]: [DonorStatus.FULLY_DISMANTLED],
};

/** Статусы, в которых с машины уже снимают детали. */
const DISMANTLING_STARTED = new Set<DonorStatus>([
  DonorStatus.DISMANTLING,
  DonorStatus.PARTIALLY_DISMANTLED,
  DonorStatus.FULLY_DISMANTLED,
]);

/** Значения до Phase 1: их ещё может прислать старая версия приложения. */
const LEGACY_STATUSES: Record<string, DonorStatus> = {
  awaiting: DonorStatus.WAITING_FOR_DISMANTLING,
  dismantled: DonorStatus.FULLY_DISMANTLED,
  closed: DonorStatus.ARCHIVED,
};

export function parseDonorStatus(value: unknown): DonorStatus | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'string') {
    if ((Object.values(DonorStatus) as string[]).includes(value)) {
      return value as DonorStatus;
    }
    if (LEGACY_STATUSES[value]) return LEGACY_STATUSES[value];
  }
  throw new BadRequestException('Неизвестный статус донора');
}

export function allowedDonorTransitions(from: DonorStatus): DonorStatus[] {
  return TRANSITIONS[from] ?? [];
}

interface DonorDates {
  status: DonorStatus;
  dismantlingStartDate: string | null;
  dismantlingEndDate: string | null;
}

/**
 * Проверяет переход и проставляет даты разбора: начало — при первом входе в разбор,
 * конец — при полном разборе или архиве; возврат в разбор снимает дату окончания.
 */
export function planStatusChange(
  donor: DonorDates,
  to: DonorStatus,
  today: string,
): Partial<DonorDates> {
  if (to === donor.status) return {};
  if (!allowedDonorTransitions(donor.status).includes(to)) {
    throw new BadRequestException(
      `Нельзя перевести из «${DONOR_STATUS_LABELS[donor.status]}» в «${DONOR_STATUS_LABELS[to]}»`,
    );
  }

  const patch: Partial<DonorDates> = { status: to };
  if (DISMANTLING_STARTED.has(to) && !donor.dismantlingStartDate) {
    patch.dismantlingStartDate = today;
  }
  if (to === DonorStatus.FULLY_DISMANTLED && !donor.dismantlingEndDate) {
    patch.dismantlingEndDate = today;
  }
  if (
    to === DonorStatus.ARCHIVED &&
    !donor.dismantlingEndDate &&
    (donor.dismantlingStartDate || DISMANTLING_STARTED.has(donor.status))
  ) {
    patch.dismantlingEndDate = today;
  }
  if (
    to === DonorStatus.DISMANTLING ||
    to === DonorStatus.PARTIALLY_DISMANTLED
  ) {
    patch.dismantlingEndDate = null;
  }
  return patch;
}

/** Дата в часовом поясе бизнеса (сервер работает в UTC). */
export function businessToday(now = new Date()): string {
  const timeZone = process.env.APP_TIME_ZONE?.trim() || 'Asia/Almaty';
  return new Intl.DateTimeFormat('en-CA', { timeZone }).format(now);
}
