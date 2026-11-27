import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';

/** Состояние номера магазина, подключённого по QR через whatsapp-gateway. */
export type WhatsAppWebState =
  'starting' | 'qr' | 'authorized' | 'reconnecting' | 'logged_out' | 'stopped';

@Entity('whatsapp_web_instances')
export class WhatsAppWebInstance {
  /** Один номер на магазин; id инстанса в шлюзе = organizationId. */
  @PrimaryColumn({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 32, default: 'stopped' })
  state: WhatsAppWebState;

  @Column({ type: 'varchar', length: 20, nullable: true })
  phone: string | null;

  /** Почему отключился: logged_out_on_phone, banned, qr_timeout, connect_failed… */
  @Column({ type: 'varchar', length: 64, nullable: true })
  reason: string | null;

  /** Отвечает ли бот Qwen на входящие в этом канале. */
  @Column({ type: 'boolean', default: false })
  botEnabled: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
