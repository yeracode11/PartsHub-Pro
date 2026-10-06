import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Item } from './item.entity';

/** На какие машины подходит деталь: одна строка — марка, модель и, при необходимости, уточнения. */
@Entity('part_compatibility')
@Index('IDX_part_compatibility_org_make_model', [
  'organizationId',
  'make',
  'model',
])
export class PartCompatibility {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Index('IDX_part_compatibility_item')
  @Column({ type: 'int' })
  itemId: number;

  @ManyToOne(() => Item, (item) => item.compatibility, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'itemId' })
  item: Item;

  @Column({ type: 'varchar', length: 50 })
  make: string;

  @Column({ type: 'varchar', length: 80 })
  model: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  generation: string | null;

  @Column({ type: 'smallint', nullable: true })
  yearFrom: number | null;

  @Column({ type: 'smallint', nullable: true })
  yearTo: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  body: string | null;

  @Column({ type: 'varchar', length: 80, nullable: true })
  engine: string | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  transmission: string | null;
}
