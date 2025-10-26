import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { B2CController } from './b2c.controller';
import { ItemsService } from '../items/items.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { OrdersService } from '../orders/orders.service';
import { OrderItemsService } from '../order-items/order-items.service';
import { Item } from '../items/entities/item.entity';
import { Organization } from '../organizations/entities/organization.entity';
import { Order } from '../orders/entities/order.entity';
import { OrderItem } from '../order-items/entities/order-item.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Item, Organization, Order, OrderItem]),
  ],
  controllers: [B2CController],
  providers: [ItemsService, OrganizationsService, OrdersService, OrderItemsService],
  exports: [ItemsService, OrganizationsService, OrdersService],
})
export class B2CModule {}
