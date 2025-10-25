import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { User } from '../../users/entities/user.entity';
import { Customer } from '../../customers/entities/customer.entity';

export enum MessageStatus {
  SENT = 'sent',
  FAILED = 'failed',
  PENDING = 'pending',
}

@Entity('message_history')
export class MessageHistory {
  @PrimaryGeneratedColumn('increment')
  id: number;

  // Multi-tenant isolation
  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  // Кто отправил
  @Column({ type: 'uuid' })
  sentBy: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'sentBy' })
  user: User;

  // Кому отправили
  @Column({ type: 'int', nullable: true })
  customerId: number;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'customerId' })
  customer: Customer;

  @Column({ type: 'varchar', length: 20 })
  phone: string; // Номер телефона получателя

  @Column({ type: 'text' })
  message: string; // Текст отправленного сообщения

  @Column({
    type: 'enum',
    enum: MessageStatus,
    default: MessageStatus.SENT,
  })
  status: MessageStatus;

  @Column({ type: 'text', nullable: true })
  errorMessage: string | null; // Текст ошибки если не удалось отправить

  @Column({ type: 'boolean', default: false })
  isBulk: boolean; // Часть массовой рассылки

  @Column({ type: 'varchar', length: 100, nullable: true })
  campaignName: string; // Название кампании (для массовых рассылок)

  @CreateDateColumn()
  sentAt: Date;
}

