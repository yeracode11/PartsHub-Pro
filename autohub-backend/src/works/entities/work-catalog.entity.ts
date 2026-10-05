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

/**
 * Справочник работ организации: название, нормо-часы и ставка за нормо-час.
 * Цена работы = normHours * pricePerHour.
 */
@Entity('work_catalog')
@Index('IDX_work_catalog_org_name', ['organizationId', 'name'])
export class WorkCatalog {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organizationId' })
  organization: Organization;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'decimal', precision: 6, scale: 2, default: 1 })
  normHours: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  pricePerHour: number;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
