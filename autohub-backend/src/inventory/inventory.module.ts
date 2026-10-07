import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Item } from '../items/entities/item.entity';
import { Warehouse } from '../warehouses/entities/warehouse.entity';
import { AuditModule } from '../audit/audit.module';
import { ListingsModule } from '../listings/listings.module';
import { StockService } from './stock.service';
import { InventoryService } from './inventory.service';
import { WarehouseLocationsService } from './warehouse-locations.service';
import { WriteOffsService } from './write-offs.service';
import { StocktakingsService } from './stocktakings.service';
import { InventoryMovement } from './entities/inventory-movement.entity';
import { WarehouseLocation } from './entities/warehouse-location.entity';
import { WriteOff } from './entities/write-off.entity';
import { Stocktaking } from './entities/stocktaking.entity';
import { StocktakingLine } from './entities/stocktaking-line.entity';
import {
  ItemMovementsController,
  StocktakingsController,
  WarehouseLocationsController,
  WriteOffsController,
} from './inventory.controllers';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Item,
      Warehouse,
      InventoryMovement,
      WarehouseLocation,
      WriteOff,
      Stocktaking,
      StocktakingLine,
    ]),
    AuditModule,
    ListingsModule,
  ],
  controllers: [
    WarehouseLocationsController,
    WriteOffsController,
    StocktakingsController,
    ItemMovementsController,
  ],
  providers: [
    StockService,
    InventoryService,
    WarehouseLocationsService,
    WriteOffsService,
    StocktakingsService,
  ],
  exports: [StockService, InventoryService],
})
export class InventoryModule {}
