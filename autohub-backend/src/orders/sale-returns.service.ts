import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SaleReturn, SaleReturnStatus } from './entities/sale-return.entity';
import { Order } from './entities/order.entity';
import { OrderItem } from '../order-items/entities/order-item.entity';
import { InventoryService } from '../inventory/inventory.service';
import { MovementType } from '../inventory/entities/inventory-movement.entity';
import { OrdersService } from './orders.service';

@Injectable()
export class SaleReturnsService {
  constructor(
    @InjectRepository(SaleReturn)
    private readonly returnRepository: Repository<SaleReturn>,
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(OrderItem)
    private readonly orderItemRepository: Repository<OrderItem>,
    private readonly inventoryService: InventoryService,
    private readonly ordersService: OrdersService,
  ) {}

  /**
   * Возврат не меняет исходную продажу. На склад строка встаёт отдельным движением,
   * списание — следом, если деталь не возвращают в продажу.
   */
  async open(
    orderId: number,
    organizationId: string,
    userId: string | null,
    raw: { itemId?: unknown; quantity?: unknown; resolution?: unknown; refundAmount?: unknown },
  ) {
    const itemId = Number(raw.itemId);
    const quantity = Number(raw.quantity);
    if (!Number.isInteger(itemId) || itemId <= 0) {
      throw new BadRequestException('Укажите товар');
    }
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new BadRequestException('Укажите количество');
    }
    const order = await this.orderRepository.findOne({
      where: { id: orderId, organizationId },
    });
    if (!order) throw new NotFoundException('Заказ не найден');
    if (order.status === 'cancelled') {
      throw new BadRequestException('Отменённый заказ вернуть нельзя');
    }
    const line = await this.orderItemRepository.findOne({
      where: { orderId, itemId },
    });
    if (!line || line.quantity < quantity) {
      throw new BadRequestException('В заказе нет такого количества');
    }

    const resolution = raw.resolution;
    const status =
      resolution === 'restock'
        ? SaleReturnStatus.RESTOCKED
        : resolution === 'write_off'
          ? SaleReturnStatus.WRITTEN_OFF
          : resolution === undefined || resolution === null
            ? SaleReturnStatus.REQUESTED
            : null;
    if (!status) throw new BadRequestException('Укажите, вернуть на склад или списать');

    const refund =
      raw.refundAmount === undefined || raw.refundAmount === null || raw.refundAmount === ''
        ? null
        : Number(raw.refundAmount);
    if (refund !== null && (!Number.isFinite(refund) || refund < 0)) {
      throw new BadRequestException('Неверная сумма возврата денег');
    }

    const saved = await this.returnRepository.manager.transaction(async (manager) => {
      const doc = await manager.save(
        SaleReturn,
        manager.create(SaleReturn, {
          organizationId,
          orderId,
          itemId,
          quantity,
          status,
          refundAmount: refund === null ? null : refund.toFixed(2),
        }),
      );
      if (status === SaleReturnStatus.RESTOCKED || status === SaleReturnStatus.WRITTEN_OFF) {
        await this.inventoryService.apply(
          {
            organizationId,
            itemId,
            type: MovementType.RETURN,
            quantityDelta: quantity,
            userId,
            documentType: 'return',
            documentId: doc.id,
            reason: 'возврат от покупателя',
          },
          manager,
        );
      }
      if (status === SaleReturnStatus.WRITTEN_OFF) {
        await this.inventoryService.apply(
          {
            organizationId,
            itemId,
            type: MovementType.WRITE_OFF,
            quantityDelta: -quantity,
            userId,
            documentType: 'return',
            documentId: doc.id,
            reason: 'возврат не в продажу',
          },
          manager,
        );
      }
      return doc;
    });

    if (refund && refund > 0) {
      await this.ordersService.refundPayment(
        orderId,
        organizationId,
        { amount: refund, method: 'cash', idempotencyKey: `return-${saved.id}` },
        userId,
      );
    }
    if (order.status === 'completed' || order.status === 'delivered') {
      await this.orderRepository.update(
        { id: orderId, organizationId },
        { status: 'returned' },
      );
    }
    return this.ordersService.findOne(orderId, organizationId);
  }
}
