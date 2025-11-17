import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { User } from '../../users/entities/user.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { IncomingItem } from './incoming-item.entity';

export enum IncomingDocStatus {
  DRAFT = 'draft',
  DONE = 'done',
  CANCELLED = 'cancelled',
}

export enum IncomingDocType {
  USED_PARTS = 'used_parts', // Б/У разбор
  NEW_PARTS = 'new_parts', // Новые запчасти
  OWN_PRODUCTION = 'own_production', // Собственное производство
}

@Entity('incoming_docs')
export class IncomingDoc {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Multi-tenant isolation
  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  // Номер накладной (генерируется автоматически)
  @Column({ type: 'varchar', length: 50, unique: true })
  docNumber: string;

  // Дата накладной
  @Column({ type: 'date' })
  date: Date;

  // Поставщик (может быть Customer или просто строка)
  @Column({ type: 'uuid', nullable: true })
  supplierId: string | null;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'supplierId' })
  supplier: Customer | null;

  // Название поставщика (если не из справочника)
  @Column({ type: 'varchar', length: 255, nullable: true })
  supplierName: string | null;

  // Тип прихода
  @Column({
    type: 'enum',
    enum: IncomingDocType,
    default: IncomingDocType.NEW_PARTS,
  })
  type: IncomingDocType;

  // Статус
  @Column({
    type: 'enum',
    enum: IncomingDocStatus,
    default: IncomingDocStatus.DRAFT,
  })
  status: IncomingDocStatus;

  // Склад (пока просто строка, можно расширить до отдельной таблицы)
  @Column({ type: 'varchar', length: 255, nullable: true })
  warehouse: string | null;

  // Примечание
  @Column({ type: 'text', nullable: true })
  notes: string | null;

  // Фото накладной
  @Column({ type: 'jsonb', nullable: true })
  docPhotos: string[] | null;

  // Кто создал
  @Column({ type: 'uuid' })
  createdById: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'createdById' })
  createdBy: User;

  // Общая сумма
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  totalAmount: number;

  // Позиции накладной
  @OneToMany(() => IncomingItem, (item) => item.doc, { cascade: true })
  items: IncomingItem[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

