import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VehiclesController } from './vehicles.controller';
import { VehiclesService } from './vehicles.service';
import { Vehicle } from './entities/vehicle.entity';
import { Customer } from '../customers/entities/customer.entity';
import { VehicleReferenceModule } from '../vehicle-reference/vehicle-reference.module';
import { VehicleReferenceController } from '../vehicle-reference/vehicle-reference.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Vehicle, Customer]), VehicleReferenceModule],
  // Справочник регистрируется раньше GET /api/vehicles/:id, иначе «makes» становится id.
  controllers: [VehicleReferenceController, VehiclesController],
  providers: [VehiclesService],
  exports: [VehiclesService],
})
export class VehiclesModule {}

