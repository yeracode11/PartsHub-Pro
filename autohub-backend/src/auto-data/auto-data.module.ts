import { Module } from '@nestjs/common';
import { AutoDataController } from './auto-data.controller';
import { VehicleReferenceModule } from '../vehicle-reference/vehicle-reference.module';

@Module({
  imports: [VehicleReferenceModule],
  controllers: [AutoDataController],
})
export class AutoDataModule {}
