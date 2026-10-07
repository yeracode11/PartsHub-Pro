import {
  AfterLoad,
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  OneToMany,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { Warehouse } from '../../warehouses/entities/warehouse.entity';
import { DonorVehicle } from '../../donors/entities/donor-vehicle.entity';
import { PartCrossReference } from './part-cross-reference.entity';
import { PartCompatibility } from './part-compatibility.entity';

export enum ItemStatus {
  ACTIVE = 'active',
  /** Снят с продажи: не виден в публичном каталоге, остаётся в истории. */
  ARCHIVED = 'archived',
}

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
  internalCode: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  barcode: string | null;

  /** Номер как ввёл пользователь; поиск идёт по oemNormalized. */
  @Column({ type: 'varchar', length: 100, nullable: true })
  oem: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  oemNormalized: string | null;

  /** Производитель детали: Toyota, Bosch… */
  @Column({ type: 'varchar', length: 100, nullable: true })
  brand: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  category: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price: number;

  /** Закупочная цена за штуку. Видят только финансовые роли — читать через addSelect. */
  @Column({
    type: 'decimal',
    precision: 12,
    scale: 2,
    nullable: true,
    select: false,
  })
  purchaseCost: string | null;

  @Column({ type: 'varchar', length: 20, default: ItemStatus.ACTIVE })
  status: ItemStatus;

  @Column({ type: 'int', default: 0 })
  quantity: number;

  /** Зарезервировано под заказ. Доступно = quantity − reservedQuantity. */
  @Column({ type: 'int', default: 0 })
  reservedQuantity: number;

  /** Не колонка: считается при чтении из базы. */
  available: number;

  @AfterLoad()
  fillAvailable() {
    this.available = Number(this.quantity) - Number(this.reservedQuantity ?? 0);
  }

  @Column({ type: 'uuid', nullable: true })
  locationId: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  condition: string | null; // new, used, refurbished

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  imageUrl: string; // Основное изображение (для обратной совместимости)

  @Column({ type: 'jsonb', nullable: true })
  images: string[]; // Массив URL изображений

  /** Ссылки на видео работы агрегата (YouTube и т.п.). */
  @Column({ type: 'jsonb', nullable: true })
  videos: string[] | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  warehouseCell: string | null; // Ячейка хранения на складе

  @Column({ type: 'uuid', nullable: true })
  warehouseId: string | null;

  @ManyToOne(() => Warehouse, (warehouse) => warehouse.items, {
    nullable: true,
  })
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

  @OneToMany(() => PartCrossReference, (ref) => ref.item)
  crossReferences: PartCrossReference[];

  @OneToMany(() => PartCompatibility, (fit) => fit.item)
  compatibility: PartCompatibility[];

  @Column({ type: 'boolean', default: false })
  synced: boolean; // Для оффлайн синхронизации

  @Column({ type: 'boolean', default: false })
  syncedToB2C: boolean; // Синхронизирован с B2C магазином

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
