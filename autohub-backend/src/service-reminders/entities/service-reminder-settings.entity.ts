import { Entity, PrimaryColumn, Column, UpdateDateColumn } from 'typeorm';

/** Настройки автонапоминаний о ТО для организации. По умолчанию выключены. */
@Entity('service_reminder_settings')
export class ServiceReminderSettings {
  @PrimaryColumn({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'boolean', default: false })
  enabled: boolean;

  /** За сколько дней до даты ТО писать клиенту. */
  @Column({ type: 'int', default: 3 })
  daysBefore: number;

  /** Подключение WhatsApp (Meta), с номера которого отправляем. */
  @Column({ type: 'uuid', nullable: true })
  connectionId: string | null;

  /** Последний известный статус шаблона в Meta: APPROVED, PENDING, REJECTED, MISSING. */
  @Column({ type: 'varchar', length: 32, nullable: true })
  templateStatus: string | null;

  @Column({ type: 'text', nullable: true })
  templateError: string | null;

  @UpdateDateColumn()
  updatedAt: Date;
}
