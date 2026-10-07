import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ListingChannel, ListingStatus } from '../marketplace-adapter';

@Entity('listings')
@Index('UQ_listings_item_channel', ['organizationId', 'itemId', 'channel'], {
  unique: true,
})
@Index('IDX_listings_sync', ['organizationId', 'status', 'nextAttemptAt'])
export class Listing {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organizationId: string;

  @Column({ type: 'int' })
  itemId: number;

  @Column({ type: 'varchar', length: 20 })
  channel: ListingChannel;

  @Column({ type: 'varchar', length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'jsonb', default: [] })
  photos: string[];

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  price: string;

  @Column({ type: 'int', default: 0 })
  quantity: number;

  @Column({ type: 'varchar', length: 20, default: ListingStatus.DRAFT })
  status: ListingStatus;

  @Column({ type: 'varchar', length: 80, nullable: true })
  externalId: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  publishedAt: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  nextAttemptAt: Date | null;

  @Column({ type: 'varchar', length: 300, nullable: true })
  lastSyncError: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
