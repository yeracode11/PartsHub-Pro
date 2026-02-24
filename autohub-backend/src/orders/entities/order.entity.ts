import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { OrderItem } from '../../order-items/entities/order-item.entity';
import { User } from '../../users/entities/user.entity';
import { Vehicle } from '../../vehicles/entities/vehicle.entity';

@Entity('orders')
@Unique(['organizationId', 'orderNumber']) // Unique constraint per organization
export class Order {
  @PrimaryGeneratedColumn('increment')
  id: number;

  // Multi-tenant isolation
  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 50 })
  orderNumber: string; // ORD-2025-001

  @Column({ type: 'int', nullable: true })
  customerId: number;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'customerId' })
  customer: Customer;

  // Автомобиль для которого выполняется заказ (опционально)
  @Column({ type: 'int', nullable: true })
  vehicleId: number;

  @ManyToOne(() => Vehicle, (vehicle) => vehicle.orders, { nullable: true })
  @JoinColumn({ name: 'vehicleId' })
  vehicle: Vehicle;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  totalAmount: number;

  @Column({
    type: 'varchar',
    length: 50,
    default: 'pending',
  })
  status: string; // pending, processing, completed, cancelled

  @Column({
    type: 'varchar',
    length: 50,
    default: 'pending',
  })
  paymentStatus: string; // pending, paid, partially_paid

  @Column({ type: 'text', nullable: true })
  notes: string;

  @Column({ type: 'text', nullable: true })
  shippingAddress: string; // Адрес доставки для B2C заказов

  @Column({ type: 'boolean', default: false })
  synced: boolean;

  @Column({ type: 'boolean', default: false })
  isB2C: boolean; // Флаг: заказ из B2C магазина

  @Column({ type: 'uuid', nullable: true })
  createdByUserId: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'createdByUserId' })
  createdBy: User | null;

  @Column({ type: 'timestamptz', nullable: true })
  reservedUntil: Date | null; // Срок резерва (для запчастей)

  @Column({ type: 'jsonb', nullable: true })
  workStages: OrderWorkStage[] | null; // Этапы заказ-наряда (для автосервисов)

  @OneToMany(() => OrderItem, (orderItem) => orderItem.order, { cascade: true })
  items: OrderItem[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

export interface OrderWorkStageItem {
  id: string;
  title: string;
  done: boolean;
  doneAt?: string | null;
}

export interface OrderWorkStage {
  id: string;
  title: string;
  items: OrderWorkStageItem[];
}
