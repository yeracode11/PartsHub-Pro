import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * Журнал напоминаний. Уникальность (организация, машина, дата ТО) не даёт
 * отправить одно и то же напоминание дважды.
 */
@Entity('service_reminder_log')
@Index('UQ_service_reminder_log_due', ['organizationId', 'vehicleId', 'dueDate'], {
  unique: true,
})
export class ServiceReminderLog {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  vehicleId: number;

  @Column({ type: 'int', nullable: true })
  customerId: number | null;

  /** Дата ТО, о которой напоминали. */
  @Column({ type: 'date' })
  dueDate: string;

  @Column({ type: 'varchar', length: 16 })
  status: 'sent' | 'failed';

  @Column({ type: 'varchar', length: 128, nullable: true })
  messageId: string | null;

  @Column({ type: 'text', nullable: true })
  error: string | null;

  @Column({ type: 'int', default: 1 })
  attempts: number;

  @Column({ type: 'timestamp', default: () => 'now()' })
  lastAttemptAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
