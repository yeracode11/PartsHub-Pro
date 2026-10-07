import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { StocktakingLine } from './stocktaking-line.entity';

export enum StocktakingStatus {
  DRAFT = 'draft',
  APPROVED = 'approved',
  CANCELLED = 'cancelled',
}

@Entity('stocktakings')
@Index('IDX_stocktakings_org_status', ['organizationId', 'status'])
export class Stocktaking {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'uuid' })
  warehouseId: string;

  @Column({ type: 'varchar', length: 20, default: StocktakingStatus.DRAFT })
  status: StocktakingStatus;

  @Column({ type: 'uuid', nullable: true })
  createdByUserId: string | null;

  @Column({ type: 'uuid', nullable: true })
  approvedByUserId: string | null;

  @Column({ type: 'timestamp', nullable: true })
  approvedAt: Date | null;

  @OneToMany(() => StocktakingLine, (line) => line.stocktaking)
  lines: StocktakingLine[];

  @CreateDateColumn()
  createdAt: Date;
}
