import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';
import { Order } from '../orders/entities/order.entity';
import { Item } from '../items/entities/item.entity';
import { OrderItem } from '../order-items/entities/order-item.entity';
import { IncomingDoc } from '../incoming/entities/incoming-doc.entity';
import { OrganizationsModule } from '../organizations/organizations.module';

@Module({
  imports: [TypeOrmModule.forFeature([Order, Item, OrderItem, IncomingDoc]), OrganizationsModule],
  controllers: [DashboardController],
  providers: [DashboardService],
  exports: [DashboardService],
})
export class DashboardModule {}

