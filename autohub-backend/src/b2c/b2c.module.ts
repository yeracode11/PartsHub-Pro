import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { B2CController } from './b2c.controller';
import { Order } from '../orders/entities/order.entity';
import { ItemsModule } from '../items/items.module';
import { OrganizationsModule } from '../organizations/organizations.module';
import { OrdersModule } from '../orders/orders.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Order]),
    ItemsModule,
    OrganizationsModule,
    OrdersModule,
  ],
  controllers: [B2CController],
  providers: [],
  exports: [],
})
export class B2CModule {}
