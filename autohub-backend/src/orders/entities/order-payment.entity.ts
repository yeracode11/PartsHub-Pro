import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Order } from './order.entity';

export type OrderPaymentMethod = 'cash' | 'card';

@Entity('order_payments')
@Index('IDX_order_payments_org_created', ['organizationId', 'createdAt'])
export class OrderPayment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  orderId: number;

  @ManyToOne(() => Order, (order) => order.payments, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'orderId' })
  order: Order;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: number;

  @Column({ type: 'varchar', length: 20 })
  method: OrderPaymentMethod;

  @Column({ type: 'uuid', nullable: true })
  createdByUserId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
