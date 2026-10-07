import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { VehicleModel } from './vehicle-model.entity';

/** Глобальный справочник марок. Не копируется на организацию. */
@Entity('vehicle_makes')
@Index('UQ_vehicle_makes_slug', ['slug'], { unique: true })
export class VehicleMake {
  @PrimaryGeneratedColumn('increment')
  id: number;

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

  @OneToMany(() => VehicleModel, (model) => model.make)
  models: VehicleModel[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
