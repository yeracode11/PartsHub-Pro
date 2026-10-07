import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, In, LessThan, Repository } from 'typeorm';
import { Order } from './entities/order.entity';
import { Reservation, ReservationStatus } from './entities/reservation.entity';
import { OrderItemsService } from '../order-items/order-items.service';

const HOLD_DAYS = 3;
const TICK_MS = 60_000;

@Injectable()
export class ReservationsService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @InjectRepository(Reservation)
    private readonly reservationRepository: Repository<Reservation>,
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    private readonly orderItemsService: OrderItemsService,
    private readonly dataSource: DataSource,
  ) {}

  onModuleInit() {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => {
      void this.expireDue().catch(() => undefined);
    }, TICK_MS);
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async replaceForOrder(
    manager: EntityManager,
    input: {
      organizationId: string;
      orderId: number;
      userId?: string | null;
      expiresAt?: Date | null;
      lines: Array<{ itemId: number; quantity: number }>;
    },
  ) {
    await manager.update(
      Reservation,
      { orderId: input.orderId, organizationId: input.organizationId },
      { status: ReservationStatus.CANCELLED },
    );
    const expiresAt =
      input.expiresAt ?? new Date(Date.now() + HOLD_DAYS * 24 * 60 * 60 * 1000);
    if (input.lines.length === 0) return;
    await manager.insert(
      Reservation,
      input.lines.map((line) => ({
        organizationId: input.organizationId,
        itemId: line.itemId,
        quantity: line.quantity,
        status: ReservationStatus.ACTIVE,
        orderId: input.orderId,
        expiresAt,
        userId: input.userId ?? null,
      })),
    );
  }

  async markConverted(orderId: number, organizationId: string, manager: EntityManager) {
    await manager.update(
      Reservation,
      {
        orderId,
        organizationId,
        status: ReservationStatus.ACTIVE,
      },
      { status: ReservationStatus.CONVERTED },
    );
  }

  async cancelForOrder(orderId: number, organizationId: string, manager: EntityManager) {
    await manager.update(
      Reservation,
      { orderId, organizationId, status: ReservationStatus.ACTIVE },
      { status: ReservationStatus.CANCELLED },
    );
  }

  /** Каждая организация закрывается отдельной транзакцией. */
  async expireDue() {
    const due = await this.reservationRepository.find({
      where: {
        status: ReservationStatus.ACTIVE,
        expiresAt: LessThan(new Date()),
      },
      take: 200,
    });
    const byOrg = new Map<string, Reservation[]>();
    for (const row of due) {
      const list = byOrg.get(row.organizationId) ?? [];
      list.push(row);
      byOrg.set(row.organizationId, list);
    }
    for (const [organizationId, rows] of byOrg) {
      await this.dataSource.transaction(async (manager) => {
        const orderIds = [
          ...new Set(rows.map((row) => row.orderId).filter((id): id is number => !!id)),
        ];
        for (const orderId of orderIds) {
          const order = await manager.findOne(Order, {
            where: { id: orderId, organizationId },
          });
          if (order?.stockHold === 'reserve') {
            await this.orderItemsService.releaseLines(orderId, manager, 'reserve');
            await manager.update(
              Order,
              { id: orderId, organizationId },
              { stockHold: 'none', status: 'pending' },
            );
          }
        }
        await manager.update(
          Reservation,
          { id: In(rows.map((row) => row.id)), organizationId },
          { status: ReservationStatus.EXPIRED },
        );
      });
    }
  }
}
