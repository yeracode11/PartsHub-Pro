import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum WriteOffReason {
  DAMAGED = 'damaged',
  LOST = 'lost',
  DEFECT = 'defect',
  OTHER = 'other',
}

@Entity('write_offs')
@Index('IDX_write_offs_org_created', ['organizationId', 'createdAt'])
export class WriteOff {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  itemId: number;

  @Column({ type: 'int' })
  quantity: number;

  @Column({ type: 'varchar', length: 20 })
  reason: WriteOffReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  note: string | null;

  @Column({ type: 'uuid', nullable: true })
  userId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
