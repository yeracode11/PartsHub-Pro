import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { Item } from '../../items/entities/item.entity';

export enum DonorStatus {
  PURCHASED = 'purchased', // Куплен, ещё не на площадке
  WAITING_FOR_DISMANTLING = 'waiting_for_dismantling', // На площадке, ждёт разбора
  DISMANTLING = 'dismantling', // В разборе: детали снимаются и ставятся на склад
  PARTIALLY_DISMANTLED = 'partially_dismantled', // Сняли нужное, разбор на паузе
  FULLY_DISMANTLED = 'fully_dismantled', // Разобран полностью, детали продаются
  ARCHIVED = 'archived', // Остатки списаны / кузов сдан, учёт закрыт
}

export enum DonorTransmission {
  MANUAL = 'manual',
  AUTOMATIC = 'automatic',
  CVT = 'cvt',
  ROBOT = 'robot',
}

export enum DonorDrivetrain {
  FWD = 'fwd',
  RWD = 'rwd',
  AWD = 'awd',
}

/** Машина, купленная целиком для разбора на запчасти. */
@Entity('donor_vehicles')
@Index('IDX_donor_vehicles_org_status', ['organizationId', 'status'])
@Index('IDX_donor_vehicles_org_created', ['organizationId', 'createdAt'])
@Index('IDX_donor_vehicles_org_vin', ['organizationId', 'vin'])
export class DonorVehicle {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 50 })
  brand: string;

  @Column({ type: 'varchar', length: 50 })
  model: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  generation: string | null; // XV70, E90

  /** Ссылка на общий справочник. Текст brand/model/generation остаётся для старых клиентов. */
  @Column({ type: 'int', nullable: true })
  makeId: number | null;

  @Column({ type: 'int', nullable: true })
  modelId: number | null;

  @Column({ type: 'int', nullable: true })
  generationId: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  body: string | null; // седан, ACV40

  @Column({ type: 'int', nullable: true })
  year: number | null;

  // VIN или номер кузова (у японских авто VIN часто отсутствует)
  @Column({ type: 'varchar', length: 30, nullable: true })
  vin: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  engine: string | null; // 2AR-FE

  @Column({
    type: 'decimal',
    precision: 3,
    scale: 1,
    nullable: true,
    transformer: {
      to: (value: number | null | undefined) => value,
      from: (value: string | null) => (value === null ? null : Number(value)),
    },
  })
  engineVolume: number | null; // литры

  @Column({ type: 'varchar', length: 20, nullable: true })
  transmission: DonorTransmission | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  drivetrain: DonorDrivetrain | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  color: string | null;

  @Column({ type: 'int', nullable: true })
  mileage: number | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  purchasePrice: number;

  // Доставка, растаможка, эвакуатор
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  deliveryCost: number;

  // Работа разборщиков
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  dismantlingCost: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  otherCosts: number;

  // Доход вне склада: сдача кузова на металл и т.п.
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  scrapIncome: number;

  @Column({ type: 'date', nullable: true })
  purchaseDate: Date | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  source: string | null; // Аукцион, продавец

  @Column({ type: 'date', nullable: true })
  dismantlingStartDate: string | null; // YYYY-MM-DD

  @Column({ type: 'date', nullable: true })
  dismantlingEndDate: string | null;

  @Column({
    type: 'enum',
    enum: DonorStatus,
    default: DonorStatus.PURCHASED,
  })
  status: DonorStatus;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({ type: 'jsonb', nullable: true })
  photos: string[] | null;

  @OneToMany(() => Item, (item) => item.donor)
  parts: Item[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
