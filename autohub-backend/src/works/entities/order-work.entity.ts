import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Order } from '../../orders/entities/order.entity';
import { User } from '../../users/entities/user.entity';
import { WorkCatalog } from './work-catalog.entity';

/**
 * Работа в заказ-наряде. Снимок названия, нормо-часов и ставки фиксируется
 * на момент добавления, чтобы изменение справочника не меняло старые заказы.
 */
@Entity('order_works')
export class OrderWork {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int' })
  orderId: number;

  @ManyToOne(() => Order, (order) => order.works, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'orderId' })
  order: Order;

  @Column({ type: 'int', nullable: true })
  workCatalogId: number | null;

  @ManyToOne(() => WorkCatalog, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'workCatalogId' })
  workCatalog: WorkCatalog | null;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'decimal', precision: 6, scale: 2, default: 1 })
  normHours: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  pricePerHour: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  subtotal: number;

  @Column({ type: 'uuid', nullable: true })
  performerId: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'performerId' })
  performer: User | null;

  @Column({ type: 'boolean', default: false })
  done: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
