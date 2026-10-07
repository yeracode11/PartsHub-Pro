import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Stocktaking } from './stocktaking.entity';

@Entity('stocktaking_lines')
@Index('UQ_stocktaking_lines_item', ['stocktakingId', 'itemId'], {
  unique: true,
})
export class StocktakingLine {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'uuid' })
  stocktakingId: string;

  @ManyToOne(() => Stocktaking, (doc) => doc.lines, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'stocktakingId' })
  stocktaking: Stocktaking;

  @Column({ type: 'int' })
  itemId: number;

  /** Остаток в системе на момент добавления строки. */
  @Column({ type: 'int' })
  expectedQuantity: number;

  /** Сколько насчитали. null — строку ещё не сканировали. */
  @Column({ type: 'int', nullable: true })
  countedQuantity: number | null;
}
