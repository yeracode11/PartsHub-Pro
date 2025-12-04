import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WarehousesService } from './warehouses.service';
import { WarehousesController } from './warehouses.controller';
import { TransfersService } from './transfers.service';
import { TransfersController } from './transfers.controller';
import { Warehouse } from './entities/warehouse.entity';
import { WarehouseTransfer } from './entities/warehouse-transfer.entity';
import { Item } from '../items/entities/item.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Warehouse, WarehouseTransfer, Item])],
  controllers: [WarehousesController, TransfersController],
  providers: [WarehousesService, TransfersService],
  exports: [WarehousesService, TransfersService],
})
export class WarehousesModule {}

