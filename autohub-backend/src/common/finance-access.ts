import { UserRole } from './enums/user-role.enum';

/** Закупочные цены, себестоимость и прибыль видят только владелец и менеджер. */
const FINANCE_ROLES: string[] = [
  UserRole.OWNER,
  UserRole.MANAGER,
  UserRole.SUPERADMIN,
];

export const canSeeFinance = (user: { role?: string } | null | undefined) =>
  FINANCE_ROLES.includes(user?.role ?? '');
