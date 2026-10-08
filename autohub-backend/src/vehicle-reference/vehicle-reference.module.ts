import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VehicleMake } from './entities/vehicle-make.entity';
import { VehicleModel } from './entities/vehicle-model.entity';
import { VehicleGeneration } from './entities/vehicle-generation.entity';
import { VehicleReferenceService } from './vehicle-reference.service';

@Module({
  imports: [TypeOrmModule.forFeature([VehicleMake, VehicleModel, VehicleGeneration])],
  providers: [VehicleReferenceService],
  exports: [VehicleReferenceService],
})
export class VehicleReferenceModule {}
