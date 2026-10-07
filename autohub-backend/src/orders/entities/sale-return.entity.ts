import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum SaleReturnStatus {
  REQUESTED = 'requested',
  INSPECTION = 'inspection',
  RESTOCKED = 'restocked',
  WRITTEN_OFF = 'written_off',
}

@Entity('sale_returns')
@Index('IDX_sale_returns_order', ['organizationId', 'orderId'])
export class SaleReturn {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  orderId: number;

  @Column({ type: 'int' })
  itemId: number;

  @Column({ type: 'int' })
  quantity: number;

  @Column({
    type: 'varchar',
    length: 20,
    default: SaleReturnStatus.REQUESTED,
  })
  status: SaleReturnStatus;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  refundAmount: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
