import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Vehicle } from './vehicle.entity';

/**
 * Запись сервисной истории автомобиля клиента: что и на каком пробеге делали.
 * Поля lastService* / nextService* в Vehicle — кэш последней записи для списков.
 */
@Entity('vehicle_service_records')
@Index('IDX_vehicle_service_records_vehicle', ['organizationId', 'vehicleId', 'serviceDate'])
export class VehicleServiceRecord {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  vehicleId: number;

  @ManyToOne(() => Vehicle, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'vehicleId' })
  vehicle: Vehicle;

  @Column({ type: 'date' })
  serviceDate: string;

  @Column({ type: 'int' })
  mileage: number;

  /** Что сделано: «Замена масла и фильтров» и т.п. */
  @Column({ type: 'text', nullable: true })
  description: string | null;

  /** Заказ-наряд, по которому делали работы (если есть). */
  @Column({ type: 'int', nullable: true })
  orderId: number | null;

  @Column({ type: 'int', nullable: true })
  nextServiceMileage: number | null;

  @Column({ type: 'date', nullable: true })
  nextServiceDate: string | null;

  @Column({ type: 'uuid', nullable: true })
  createdById: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
