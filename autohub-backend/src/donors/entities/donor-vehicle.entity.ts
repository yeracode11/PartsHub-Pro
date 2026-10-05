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
  AWAITING = 'awaiting', // Куплен, ждёт разбора
  DISMANTLING = 'dismantling', // В разборе: детали снимаются и ставятся на склад
  DISMANTLED = 'dismantled', // Разобран полностью, детали продаются
  CLOSED = 'closed', // Остатки списаны / кузов сдан, учёт закрыт
}

/** Машина, купленная целиком для разбора на запчасти. */
@Entity('donor_vehicles')
@Index('IDX_donor_vehicles_org_status', ['organizationId', 'status'])
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

  @Column({ type: 'int', nullable: true })
  year: number | null;

  // VIN или номер кузова (у японских авто VIN часто отсутствует)
  @Column({ type: 'varchar', length: 30, nullable: true })
  vin: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  engine: string | null; // 2AR-FE, 2.5

  @Column({ type: 'varchar', length: 50, nullable: true })
  color: string | null;

  @Column({ type: 'int', nullable: true })
  mileage: number | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  purchasePrice: number;

  // Доставка, растаможка, эвакуатор, работа разборщиков
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  extraCosts: number;

  // Доход вне склада: сдача кузова на металл и т.п.
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  scrapIncome: number;

  @Column({ type: 'date', nullable: true })
  purchaseDate: Date | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  source: string | null; // Аукцион, продавец

  @Column({
    type: 'enum',
    enum: DonorStatus,
    default: DonorStatus.AWAITING,
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
