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
import { WhatsAppConnection } from './whatsapp-connection.entity';

export enum MessageDirection {
  INBOUND = 'inbound',
  OUTBOUND = 'outbound',
}

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

  @Column({ type: 'uuid', nullable: true })
  whatsappConnectionId: string | null;

  @ManyToOne(() => WhatsAppConnection, { nullable: true })
  @JoinColumn({ name: 'whatsappConnectionId' })
  whatsappConnection: WhatsAppConnection | null;

  @Column({
    type: 'enum',
    enum: MessageDirection,
    default: MessageDirection.OUTBOUND,
  })
  direction: MessageDirection;

  /** Meta wamid — idempotency для inbound webhook. */
  @Column({ type: 'varchar', length: 255, nullable: true, unique: true })
  externalMessageId: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  messageType: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown> | null;

  // Кто отправил (исходящие Green/Manual; inbound — null)
  @Column({ type: 'uuid', nullable: true })
  sentBy: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'sentBy' })
  user: User | null;

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

