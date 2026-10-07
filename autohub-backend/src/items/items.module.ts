import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ItemsController } from './items.controller';
import { ItemsService } from './items.service';
import { Item } from './entities/item.entity';
import { PartCrossReference } from './entities/part-cross-reference.entity';
import { PartCompatibility } from './entities/part-compatibility.entity';
import { AuditModule } from '../audit/audit.module';
import { InventoryModule } from '../inventory/inventory.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Item, PartCrossReference, PartCompatibility]),
    AuditModule,
    InventoryModule,
  ],
  controllers: [ItemsController],
  providers: [ItemsService],
  exports: [ItemsService],
})
export class ItemsModule {}
