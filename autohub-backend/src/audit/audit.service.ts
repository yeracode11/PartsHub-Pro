import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, Repository } from 'typeorm';
import { AuditChanges, AuditLog } from './entities/audit-log.entity';

export interface AuditEntry {
  organizationId: string;
  userId?: string | null;
  entityType: string;
  entityId: string | number;
  action: string;
  changes: AuditChanges;
}

export interface AuditHistoryItem {
  id: string;
  action: string;
  changes: AuditChanges;
  createdAt: Date;
  userId: string | null;
  userName: string | null;
}

const HISTORY_LIMIT = 100;

type Comparable = string | number | null;

function comparable(value: unknown): Comparable {
  if (value === undefined || value === null || value === '') return null;
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === 'number') return value;
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  const asNumber = Number(text);
  return text.trim() !== '' && Number.isFinite(asNumber) ? asNumber : text;
}

/**
 * Только реально изменившиеся поля; «900000.00» и 900000 считаются равными.
 * При создании (before = null) пустые и нулевые значения не пишутся.
 */
export function diffFields(
  before: Record<string, unknown> | null,
  after: Record<string, unknown>,
  fields: readonly string[],
): AuditChanges {
  const changes: AuditChanges = {};
  for (const field of fields) {
    if (!(field in after)) continue;
    const from = before ? comparable(before[field]) : null;
    const to = comparable(after[field]);
    if (!before && (to === null || to === 0)) continue;
    if (from !== to) changes[field] = { from, to };
  }
  return changes;
}

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog)
    private readonly auditRepository: Repository<AuditLog>,
  ) {}

  /** Пустые изменения не пишутся. Передайте manager, чтобы запись попала в ту же транзакцию. */
  async record(entry: AuditEntry, manager?: EntityManager): Promise<void> {
    if (Object.keys(entry.changes).length === 0) return;
    const repo = manager
      ? manager.getRepository(AuditLog)
      : this.auditRepository;
    await repo.insert({
      organizationId: entry.organizationId,
      userId: entry.userId ?? null,
      entityType: entry.entityType,
      entityId: String(entry.entityId),
      action: entry.action,
      changes: entry.changes,
    });
  }

  async history(
    organizationId: string,
    entityType: string,
    entityId: string | number,
  ): Promise<AuditHistoryItem[]> {
    const rows = await this.auditRepository
      .createQueryBuilder('a')
      .leftJoin('users', 'u', 'u.id = a."userId"')
      .select([
        'a.id AS id',
        'a.action AS action',
        'a.changes AS changes',
        'a."createdAt" AS "createdAt"',
        'a."userId" AS "userId"',
        'u.name AS "userName"',
      ])
      .where('a."organizationId" = :organizationId', { organizationId })
      .andWhere('a."entityType" = :entityType', { entityType })
      .andWhere('a."entityId" = :entityId', { entityId: String(entityId) })
      .orderBy('a."createdAt"', 'DESC')
      .limit(HISTORY_LIMIT)
      .getRawMany<AuditHistoryItem>();
    return rows.map((row) => ({ ...row, id: String(row.id) }));
  }
}
