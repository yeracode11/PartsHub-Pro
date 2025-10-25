import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';

export enum TemplateCategory {
  PROMO = 'promo', // Акции и скидки
  REMINDER = 'reminder', // Напоминания (ТО, оплата)
  NOTIFICATION = 'notification', // Уведомления (готов заказ)
  GREETING = 'greeting', // Поздравления
  CUSTOM = 'custom', // Пользовательские
}

@Entity('message_templates')
export class MessageTemplate {
  @PrimaryGeneratedColumn('increment')
  id: number;

  // Multi-tenant isolation
  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 100 })
  name: string; // Название шаблона

  @Column({ type: 'text' })
  content: string; // Текст сообщения с переменными {name}, {carModel}, etc.

  @Column({
    type: 'enum',
    enum: TemplateCategory,
    default: TemplateCategory.CUSTOM,
  })
  category: TemplateCategory;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @Column({ type: 'int', default: 0 })
  usageCount: number; // Сколько раз использовался

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

