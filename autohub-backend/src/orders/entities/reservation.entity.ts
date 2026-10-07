import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum ReservationStatus {
  ACTIVE = 'active',
  EXPIRED = 'expired',
  CANCELLED = 'cancelled',
  CONVERTED = 'converted_to_order',
}

@Entity('reservations')
@Index('IDX_reservations_due', ['organizationId', 'status', 'expiresAt'])
export class Reservation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  itemId: number;

  @Column({ type: 'int' })
  quantity: number;

  @Column({ type: 'varchar', length: 30, default: ReservationStatus.ACTIVE })
  status: ReservationStatus;

  @Column({ type: 'int', nullable: true })
  orderId: number | null;

  @Column({ type: 'timestamptz', nullable: true })
  expiresAt: Date | null;

  @Column({ type: 'uuid', nullable: true })
  userId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
