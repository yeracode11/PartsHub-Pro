import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum MovementType {
  RECEIVING = 'receiving',
  TRANSFER = 'transfer',
  SALE = 'sale',
  RESERVATION = 'reservation',
  RESERVATION_RELEASE = 'reservation_release',
  RETURN = 'return',
  WRITE_OFF = 'write_off',
  INVENTORY_ADJUSTMENT = 'inventory_adjustment',
}

@Entity('inventory_movements')
@Index('IDX_inventory_movements_item', [
  'organizationId',
  'itemId',
  'createdAt',
])
export class InventoryMovement {
  @PrimaryGeneratedColumn('increment', { type: 'bigint' })
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  itemId: number;

  @Column({ type: 'varchar', length: 30 })
  type: MovementType;

  /** На сколько изменился остаток. Минус — ушло со склада. */
  @Column({ type: 'int' })
  quantityDelta: number;

  @Column({ type: 'int' })
  quantityAfter: number;

  @Column({ type: 'int', default: 0 })
  reservedDelta: number;

  @Column({ type: 'int' })
  reservedAfter: number;

  @Column({ type: 'uuid', nullable: true })
  warehouseId: string | null;

  @Column({ type: 'uuid', nullable: true })
  locationId: string | null;

  @Column({ type: 'varchar', length: 40, nullable: true })
  documentType: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  documentId: string | null;

  @Column({ type: 'varchar', length: 200, nullable: true })
  reason: string | null;

  @Column({ type: 'uuid', nullable: true })
  userId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
