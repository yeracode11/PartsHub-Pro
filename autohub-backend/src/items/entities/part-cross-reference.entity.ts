import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Item } from './item.entity';

export enum CrossReferenceType {
  /** Другой оригинальный номер той же детали (Toyota ↔ Lexus, замена номера). */
  ALTERNATIVE = 'alternative',
  /** Неоригинальный аналог. */
  AFTERMARKET = 'aftermarket',
}

/**
 * Номер, под которым ещё ищут эту деталь. Пока строки принадлежат товару;
 * общая база кроссов организации появится импортом с itemId = NULL.
 */
@Entity('part_cross_references')
@Index('IDX_part_cross_references_org_oem', ['organizationId', 'oemNormalized'])
@Index('UQ_part_cross_references_item_oem', ['itemId', 'oemNormalized'], {
  unique: true,
})
export class PartCrossReference {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  itemId: number;

  @ManyToOne(() => Item, (item) => item.crossReferences, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'itemId' })
  item: Item;

  @Column({ type: 'varchar', length: 100 })
  oem: string;

  @Column({ type: 'varchar', length: 100 })
  oemNormalized: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  brand: string | null;

  @Column({
    type: 'varchar',
    length: 20,
    default: CrossReferenceType.ALTERNATIVE,
  })
  type: CrossReferenceType;
}
