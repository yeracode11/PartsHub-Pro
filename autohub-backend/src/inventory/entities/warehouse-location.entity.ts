import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Warehouse } from '../../warehouses/entities/warehouse.entity';

export enum LocationKind {
  ZONE = 'zone',
  RACK = 'rack',
  CELL = 'cell',
}

/** Зона, стеллаж или ячейка внутри склада. */
@Entity('warehouse_locations')
@Index('UQ_warehouse_locations_code', ['warehouseId', 'code'], { unique: true })
export class WarehouseLocation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'uuid' })
  warehouseId: string;

  @ManyToOne(() => Warehouse, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'warehouseId' })
  warehouse: Warehouse;

  @Column({ type: 'uuid', nullable: true })
  parentId: string | null;

  @Column({ type: 'varchar', length: 10 })
  kind: LocationKind;

  @Column({ type: 'varchar', length: 100 })
  code: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  barcode: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
