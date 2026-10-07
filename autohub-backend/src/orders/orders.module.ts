import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { Order } from './entities/order.entity';
import { OrderPayment } from './entities/order-payment.entity';
import { Reservation } from './entities/reservation.entity';
import { SaleReturn } from './entities/sale-return.entity';
import { OrderItem } from '../order-items/entities/order-item.entity';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import { Customer } from '../customers/entities/customer.entity';
import { OrderItemsModule } from '../order-items/order-items.module';
import { OrganizationsModule } from '../organizations/organizations.module';
import { CustomersModule } from '../customers/customers.module';
import { WhatsAppModule } from '../whatsapp/whatsapp.module';
import { WorksModule } from '../works/works.module';
import { InventoryModule } from '../inventory/inventory.module';
import { ReservationsService } from './reservations.service';
import { SaleReturnsService } from './sale-returns.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Order,
      OrderPayment,
      Reservation,
      SaleReturn,
      OrderItem,
      Vehicle,
      Customer,
    ]),
    OrderItemsModule,
    OrganizationsModule,
    CustomersModule,
    WhatsAppModule,
    WorksModule,
    InventoryModule,
  ],
  controllers: [OrdersController],
  providers: [OrdersService, ReservationsService, SaleReturnsService],
  exports: [OrdersService],
})
export class OrdersModule {}

