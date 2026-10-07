import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { VehicleMake } from './vehicle-make.entity';
import { VehicleGeneration } from './vehicle-generation.entity';

@Entity('vehicle_models')
@Index('UQ_vehicle_models_make_slug', ['makeId', 'slug'], { unique: true })
export class VehicleModel {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ type: 'int' })
  makeId: number;

  @ManyToOne(() => VehicleMake, (make) => make.models, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'makeId' })
  make: VehicleMake;

  @Column({ type: 'varchar', length: 80 })
  name: string;

  @Column({ type: 'varchar', length: 80 })
  slug: string;

  @Column({ type: 'jsonb', default: [] })
  synonyms: string[];

  @Column({ default: true })
  isActive: boolean;

  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  @OneToMany(() => VehicleGeneration, (generation) => generation.model)
  generations: VehicleGeneration[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
