import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { VehicleModel } from './vehicle-model.entity';

@Entity('vehicle_generations')
@Index('UQ_vehicle_generations_model_slug', ['modelId', 'slug'], { unique: true })
export class VehicleGeneration {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'int' })
  modelId: number;

  @ManyToOne(() => VehicleModel, (model) => model.generations, {
    onDelete: 'RESTRICT',
  })
  @JoinColumn({ name: 'modelId' })
  model: VehicleModel;

  @Column({ type: 'varchar', length: 80 })
  name: string;

  @Column({ type: 'varchar', length: 80 })
  slug: string;

  @Column({ type: 'smallint', nullable: true })
  yearFrom: number | null;

  @Column({ type: 'smallint', nullable: true })
  yearTo: number | null;

  @Column({ type: 'jsonb', default: [] })
  synonyms: string[];

  @Column({ default: true })
  isActive: boolean;

  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
