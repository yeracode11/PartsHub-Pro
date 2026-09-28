import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Item } from '../items/entities/item.entity';
import { StockService } from './stock.service';

@Module({
  imports: [TypeOrmModule.forFeature([Item])],
  providers: [StockService],
  exports: [StockService],
})
export class InventoryModule {}
