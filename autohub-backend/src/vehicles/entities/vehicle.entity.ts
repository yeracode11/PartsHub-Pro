import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Order } from '../../orders/entities/order.entity';

export enum FuelType {
  PETROL = 'petrol',
  DIESEL = 'diesel',
  ELECTRIC = 'electric',
  HYBRID = 'hybrid',
  GAS = 'gas',
}

export enum TransmissionType {
  MANUAL = 'manual',
  AUTOMATIC = 'automatic',
  ROBOT = 'robot',
  CVT = 'cvt',
}

@Entity('vehicles')
export class Vehicle {
  @PrimaryGeneratedColumn('increment')
  id: number;

  // Multi-tenant isolation
  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  // Владелец автомобиля
  @Column({ type: 'int' })
  customerId: number;

  @ManyToOne(() => Customer, (customer) => customer.vehicles)
  @JoinColumn({ name: 'customerId' })
  customer: Customer;

  // Основная информация
  @Column({ type: 'varchar', length: 50 })
  brand: string; // Марка (Toyota, BMW, Mercedes)

  @Column({ type: 'varchar', length: 50 })
  model: string; // Модель (Camry, X5, E-Class)

  @Column({ type: 'int' })
  year: number; // Год выпуска

  @Column({ type: 'varchar', length: 50, nullable: true })
  color: string; // Цвет

  @Column({ type: 'varchar', length: 20, unique: true })
  plateNumber: string; // Госномер (А123БВ77)

  @Column({ type: 'varchar', length: 17, nullable: true, unique: true })
  vin: string; // VIN номер (17 символов)

  // Технические характеристики
  @Column({
    type: 'enum',
    enum: FuelType,
    default: FuelType.PETROL,
  })
  fuelType: FuelType;

  @Column({
    type: 'enum',
    enum: TransmissionType,
    default: TransmissionType.MANUAL,
  })
  transmission: TransmissionType;

  @Column({ type: 'varchar', length: 20, nullable: true })
  engineVolume: string; // Объем двигателя (2.0, 3.5)

  @Column({ type: 'int', nullable: true })
  enginePower: number; // Мощность (л.с.)

  // Пробег и обслуживание
  @Column({ type: 'int', default: 0 })
  currentMileage: number; // Текущий пробег (км)

  @Column({ type: 'int', nullable: true })
  lastServiceMileage: number; // Пробег при последнем ТО

  @Column({ type: 'date', nullable: true })
  lastServiceDate: Date; // Дата последнего ТО

  @Column({ type: 'int', nullable: true })
  nextServiceMileage: number; // Следующее ТО при пробеге

  @Column({ type: 'date', nullable: true })
  nextServiceDate: Date; // Следующее ТО по дате

  // Дополнительная информация
  @Column({ type: 'text', nullable: true })
  notes: string; // Примечания (особенности, проблемы)

  @Column({ type: 'varchar', length: 255, nullable: true })
  photoUrl: string; // Фото автомобиля

  @Column({ type: 'boolean', default: true })
  isActive: boolean; // Активен ли автомобиль (может быть продан)

  // История заказов для этого авто
  @OneToMany(() => Order, (order) => order.vehicle)
  orders: Order[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

