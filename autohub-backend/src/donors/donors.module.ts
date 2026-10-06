import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DonorsController } from './donors.controller';
import { DonorsService } from './donors.service';
import { DonorVehicle } from './entities/donor-vehicle.entity';
import { Item } from '../items/entities/item.entity';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [TypeOrmModule.forFeature([DonorVehicle, Item]), AuditModule],
  controllers: [DonorsController],
  providers: [DonorsService],
})
export class DonorsModule {}
