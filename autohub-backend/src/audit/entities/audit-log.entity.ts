import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type AuditChanges = Record<
  string,
  { from: string | number | null; to: string | number | null }
>;

/** Кто, когда и что поменял. Записи только добавляются, никогда не правятся. */
@Entity('audit_logs')
@Index('IDX_audit_logs_entity', [
  'organizationId',
  'entityType',
  'entityId',
  'createdAt',
])
export class AuditLog {
  @PrimaryGeneratedColumn('increment', { type: 'bigint' })
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'uuid', nullable: true })
  userId: string | null;

  @Column({ type: 'varchar', length: 50 })
  entityType: string;

  @Column({ type: 'varchar', length: 64 })
  entityId: string;

  @Column({ type: 'varchar', length: 30 })
  action: string;

  @Column({ type: 'jsonb' })
  changes: AuditChanges;

  @CreateDateColumn()
  createdAt: Date;
}
