import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';

export enum WhatsAppConnectionStatus {
  ACTIVE = 'active',
  DISABLED = 'disabled',
}

@Entity('whatsapp_connections')
@Index(['organizationId'])
@Index(['wabaId'])
export class WhatsAppConnection {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 32, unique: true })
  phoneNumberId: string;

  @Column({ type: 'varchar', length: 64, nullable: true })
  wabaId: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phoneNumber: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  displayName: string | null;

  @Column({ type: 'text' })
  accessToken: string;

  @Column({
    type: 'varchar',
    length: 32,
    default: WhatsAppConnectionStatus.ACTIVE,
  })
  status: WhatsAppConnectionStatus;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
