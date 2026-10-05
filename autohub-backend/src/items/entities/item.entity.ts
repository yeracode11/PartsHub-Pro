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
import { Warehouse } from '../../warehouses/entities/warehouse.entity';
import { DonorVehicle } from '../../donors/entities/donor-vehicle.entity';

@Entity('items')
export class Item {
  @PrimaryGeneratedColumn('increment')
  id: number;

  // Multi-tenant isolation
  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  sku: string | null; // Артикул

  @Column({ type: 'varchar', length: 100, nullable: true })
  category: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price: number;

  @Column({ type: 'int', default: 0 })
  quantity: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  condition: string | null; // new, used, refurbished

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  imageUrl: string; // Основное изображение (для обратной совместимости)

  @Column({ type: 'jsonb', nullable: true })
  images: string[]; // Массив URL изображений

  @Column({ type: 'varchar', length: 100, nullable: true })
  warehouseCell: string | null; // Ячейка хранения на складе

  @Column({ type: 'uuid', nullable: true })
  warehouseId: string | null;

  @ManyToOne(() => Warehouse, warehouse => warehouse.items, { nullable: true })
  @JoinColumn({ name: 'warehouseId' })
  warehouse: Warehouse;

  // Машина-донор, с которой снята деталь (только для авторазбора)
  @Index('IDX_items_donorId')
  @Column({ type: 'int', nullable: true })
  donorId: number | null;

  @ManyToOne(() => DonorVehicle, (donor) => donor.parts, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'donorId' })
  donor: DonorVehicle | null;

  @Column({ type: 'boolean', default: false })
  synced: boolean; // Для оффлайн синхронизации

  @Column({ type: 'boolean', default: false })
  syncedToB2C: boolean; // Синхронизирован с B2C магазином

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

