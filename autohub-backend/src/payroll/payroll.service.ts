import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OrderWork } from '../works/entities/order-work.entity';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums/user-role.enum';

@Injectable()
export class PayrollService {
  constructor(
    @InjectRepository(OrderWork)
    private readonly orderWorkRepository: Repository<OrderWork>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async report(
    organizationId: string,
    from: Date,
    to: Date,
    actor: { id: string; role: UserRole },
  ) {
    const query = this.orderWorkRepository
      .createQueryBuilder('work')
      .innerJoinAndSelect('work.order', 'order')
      .innerJoinAndSelect('work.performer', 'performer')
      .where('order.organizationId = :organizationId', { organizationId })
      .andWhere("order.status <> 'cancelled'")
      .andWhere('work.done = true')
      .andWhere('work.performerId IS NOT NULL')
      .andWhere('COALESCE(work."doneAt", work."updatedAt") >= :from', { from })
      .andWhere('COALESCE(work."doneAt", work."updatedAt") < :to', { to })
      .orderBy('COALESCE(work."doneAt", work."updatedAt")', 'DESC');

    if (actor.role === UserRole.WORKER) {
      query.andWhere('work.performerId = :performerId', { performerId: actor.id });
    }

    const works = await query.getMany();
    const openQuery = this.orderWorkRepository
      .createQueryBuilder('work')
      .innerJoinAndSelect('work.order', 'order')
      .innerJoinAndSelect('work.performer', 'performer')
      .where('order.organizationId = :organizationId', { organizationId })
      .andWhere("order.status <> 'cancelled'")
      .andWhere('work.done = false')
      .andWhere('work.performerId IS NOT NULL')
      .orderBy('work.id', 'DESC');
    if (actor.role === UserRole.WORKER) {
      openQuery.andWhere('work.performerId = :performerId', {
        performerId: actor.id,
      });
    }
    const openWorks = await openQuery.getMany();

    const grouped = new Map<string, ReturnType<PayrollService['presentMaster']>>();

    const ensure = (master: User) => {
      const current = grouped.get(master.id) ?? this.presentMaster(master);
      grouped.set(master.id, current);
      return current;
    };

    for (const work of openWorks) {
      if (!work.performer) continue;
      const current = ensure(work.performer);
      current.open.push(this.presentLine(work, work.performer));
    }

    for (const work of works) {
      if (!work.performer) continue;
      const current = ensure(work.performer);
      const line = this.presentLine(work, work.performer);
      current.lines.push(line);
      current.total = this.round(current.total + line.amount);
    }

    const masters = [...grouped.values()].sort((a, b) =>
      a.name.localeCompare(b.name, 'ru'),
    );

    return { from, to, masters };
  }

  async setWorkDone(
    organizationId: string,
    workId: number,
    done: boolean,
    actor: { id: string; role: UserRole },
  ) {
    const work = await this.orderWorkRepository.findOne({
      where: { id: workId },
      relations: ['order'],
    });
    if (!work || work.order?.organizationId !== organizationId) {
      throw new NotFoundException('Работа не найдена');
    }
    if (actor.role === UserRole.WORKER && work.performerId !== actor.id) {
      throw new ForbiddenException('Можно отметить только свою работу');
    }
    if (!work.performerId) {
      throw new ForbiddenException('У работы не указан мастер');
    }

    work.done = done;
    work.doneAt = done ? work.doneAt ?? new Date() : null;
    const saved = await this.orderWorkRepository.save(work);
    return {
      id: saved.id,
      done: saved.done,
      doneAt: saved.doneAt,
    };
  }

  private presentMaster(user: User) {
    return {
      id: user.id,
      name: user.name,
      payType: user.payType === 'hourly' ? 'hourly' : 'percent',
      payRate: Number(user.payRate ?? 40),
      total: 0,
      open: [] as Array<ReturnType<PayrollService['presentLine']>>,
      lines: [] as Array<ReturnType<PayrollService['presentLine']>>,
    };
  }

  private presentLine(work: OrderWork, user: User) {
    return {
      workId: work.id,
      orderId: work.orderId,
      orderNumber: work.order?.orderNumber ?? null,
      name: work.name,
      hours: Number(work.normHours),
      subtotal: Number(work.subtotal),
      amount: this.lineAmount(work, user),
      done: work.done,
      doneAt: work.doneAt ?? work.updatedAt,
    };
  }

  private lineAmount(work: OrderWork, user: User): number {
    const rate = Number(user.payRate ?? 40);
    if (user.payType === 'hourly') {
      return this.round(Number(work.normHours) * rate);
    }
    return this.round((Number(work.subtotal) * rate) / 100);
  }

  private round(value: number): number {
    return Math.round(value * 100) / 100;
  }
}
