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
import { Customer } from '../../customers/entities/customer.entity';
import { Vehicle } from '../../vehicles/entities/vehicle.entity';
import { User } from '../../users/entities/user.entity';
import { Order } from '../../orders/entities/order.entity';
import { ServicePost } from './service-post.entity';

export enum AppointmentStatus {
  SCHEDULED = 'scheduled',
  ARRIVED = 'arrived',
  IN_PROGRESS = 'in_progress',
  DONE = 'done',
  CANCELLED = 'cancelled',
}

@Entity('appointments')
@Index('IDX_appointments_org_start', ['organizationId', 'startsAt'])
export class Appointment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'int' })
  postId: number;

  @ManyToOne(() => ServicePost)
  @JoinColumn({ name: 'postId' })
  post: ServicePost;

  @Column({ type: 'int', nullable: true })
  customerId: number | null;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'customerId' })
  customer: Customer | null;

  @Column({ type: 'int', nullable: true })
  vehicleId: number | null;

  @ManyToOne(() => Vehicle, { nullable: true })
  @JoinColumn({ name: 'vehicleId' })
  vehicle: Vehicle | null;

  @Column({ type: 'uuid', nullable: true })
  masterId: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'masterId' })
  master: User | null;

  @Column({ type: 'timestamptz' })
  startsAt: Date;

  @Column({ type: 'timestamptz' })
  endsAt: Date;

  @Column({ type: 'varchar', length: 30, default: AppointmentStatus.SCHEDULED })
  status: AppointmentStatus;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({ type: 'int', nullable: true })
  orderId: number | null;

  @ManyToOne(() => Order, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'orderId' })
  order: Order | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
