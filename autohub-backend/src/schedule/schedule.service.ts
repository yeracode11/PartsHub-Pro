import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ServicePost } from './entities/service-post.entity';
import { Appointment, AppointmentStatus } from './entities/appointment.entity';
import { Customer } from '../customers/entities/customer.entity';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums/user-role.enum';
import { OrdersService } from '../orders/orders.service';

export class CreateAppointmentInput {
  postId: number;
  customerId?: number | null;
  vehicleId?: number | null;
  masterId?: string | null;
  startsAt: string;
  durationMinutes?: number;
  notes?: string | null;
}

export class UpdateAppointmentInput {
  postId?: number;
  customerId?: number | null;
  vehicleId?: number | null;
  masterId?: string | null;
  startsAt?: string;
  durationMinutes?: number;
  notes?: string | null;
  status?: AppointmentStatus;
}

const ACTIVE = [
  AppointmentStatus.SCHEDULED,
  AppointmentStatus.ARRIVED,
  AppointmentStatus.IN_PROGRESS,
  AppointmentStatus.DONE,
];

@Injectable()
export class ScheduleService {
  constructor(
    @InjectRepository(ServicePost)
    private readonly postRepository: Repository<ServicePost>,
    @InjectRepository(Appointment)
    private readonly appointmentRepository: Repository<Appointment>,
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
    @InjectRepository(Vehicle)
    private readonly vehicleRepository: Repository<Vehicle>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly ordersService: OrdersService,
  ) {}

  async listPosts(organizationId: string): Promise<ServicePost[]> {
    await this.ensureDefaultPosts(organizationId);
    return this.postRepository.find({
      where: { organizationId, isActive: true },
      order: { sortOrder: 'ASC', id: 'ASC' },
    });
  }

  async createPost(organizationId: string, name: string): Promise<ServicePost> {
    const trimmed = (name || '').trim();
    if (!trimmed) {
      throw new BadRequestException('Укажите название поста');
    }
    const count = await this.postRepository.count({ where: { organizationId } });
    const post = this.postRepository.create({
      organizationId,
      name: trimmed,
      sortOrder: count,
      isActive: true,
    });
    return this.postRepository.save(post);
  }

  async renamePost(organizationId: string, id: number, name: string): Promise<ServicePost> {
    const post = await this.findPost(organizationId, id);
    const trimmed = (name || '').trim();
    if (!trimmed) {
      throw new BadRequestException('Укажите название поста');
    }
    post.name = trimmed;
    return this.postRepository.save(post);
  }

  async removePost(organizationId: string, id: number): Promise<void> {
    const post = await this.findPost(organizationId, id);
    post.isActive = false;
    await this.postRepository.save(post);
  }

  async listMasters(organizationId: string) {
    const users = await this.userRepository.find({
      where: { organizationId, role: UserRole.STO, isActive: true },
      order: { name: 'ASC' },
    });
    return users.map((user) => ({ id: user.id, name: user.name }));
  }

  async listAppointments(
    organizationId: string,
    from: Date,
    to: Date,
    masterId?: string,
  ) {
    const query = this.appointmentRepository
      .createQueryBuilder('appointment')
      .leftJoinAndSelect('appointment.post', 'post')
      .leftJoinAndSelect('appointment.customer', 'customer')
      .leftJoinAndSelect('appointment.vehicle', 'vehicle')
      .leftJoinAndSelect('appointment.master', 'master')
      .where('appointment.organizationId = :organizationId', { organizationId })
      .andWhere('appointment.startsAt < :to', { to })
      .andWhere('appointment.endsAt > :from', { from });
    if (masterId) {
      query.andWhere('appointment.masterId = :masterId', { masterId });
    }
    const rows = await query.orderBy('appointment.startsAt', 'ASC').getMany();
    return rows.map((row) => this.present(row));
  }

  async createAppointment(organizationId: string, input: CreateAppointmentInput) {
    const post = await this.findPost(organizationId, Number(input.postId));
    const { startsAt, endsAt } = this.resolveWindow(input.startsAt, input.durationMinutes);
    const link = await this.resolveLink(
      organizationId,
      input.customerId,
      input.vehicleId,
      input.masterId,
    );
    await this.assertFree(post.id, startsAt, endsAt);

    const appointment = this.appointmentRepository.create({
      organizationId,
      postId: post.id,
      customerId: link.customerId,
      vehicleId: link.vehicleId,
      masterId: link.masterId,
      startsAt,
      endsAt,
      status: AppointmentStatus.SCHEDULED,
      notes: input.notes?.trim() || null,
    });
    const saved = await this.appointmentRepository.save(appointment);
    return this.findOne(organizationId, saved.id);
  }

  async updateAppointment(
    organizationId: string,
    id: number,
    input: UpdateAppointmentInput,
  ) {
    const appointment = await this.findOne(organizationId, id);
    if (input.status && !Object.values(AppointmentStatus).includes(input.status)) {
      throw new BadRequestException('Некорректный статус записи');
    }

    const postId = input.postId ? Number(input.postId) : appointment.postId;
    if (input.postId) {
      await this.findPost(organizationId, postId);
    }

    const startsAt = input.startsAt ? new Date(input.startsAt) : appointment.startsAt;
    const duration = input.durationMinutes
      ? this.normalizeDuration(input.durationMinutes)
      : Math.round((appointment.endsAt.getTime() - appointment.startsAt.getTime()) / 60000);
    const endsAt = input.startsAt || input.durationMinutes
      ? new Date(startsAt.getTime() + this.normalizeDuration(duration) * 60000)
      : appointment.endsAt;

    if (Number.isNaN(startsAt.getTime())) {
      throw new BadRequestException('Укажите время записи');
    }

    const nextStatus = input.status || appointment.status;
    if (nextStatus !== AppointmentStatus.CANCELLED) {
      await this.assertFree(postId, startsAt, endsAt, appointment.id);
    }

    if (
      input.customerId !== undefined ||
      input.vehicleId !== undefined ||
      input.masterId !== undefined
    ) {
      const link = await this.resolveLink(
        organizationId,
        input.customerId !== undefined ? input.customerId : appointment.customerId,
        input.vehicleId !== undefined ? input.vehicleId : appointment.vehicleId,
        input.masterId !== undefined ? input.masterId : appointment.masterId,
      );
      appointment.customerId = link.customerId;
      appointment.vehicleId = link.vehicleId;
      appointment.masterId = link.masterId;
    }

    appointment.postId = postId;
    appointment.startsAt = startsAt;
    appointment.endsAt = endsAt;
    appointment.status = nextStatus;
    if (input.notes !== undefined) {
      appointment.notes = input.notes?.trim() || null;
    }
    await this.appointmentRepository.save(appointment);
    return this.findOne(organizationId, id);
  }

  async createOrder(
    organizationId: string,
    id: number,
    actor?: { userId?: string; id?: string },
  ) {
    const appointment = await this.findOne(organizationId, id);
    if (appointment.orderId) {
      return appointment;
    }
    if (appointment.status === AppointmentStatus.CANCELLED) {
      throw new BadRequestException('Отменённую запись нельзя превратить в заказ');
    }

    const order = await this.ordersService.create(
      organizationId,
      {
        customerId: appointment.customerId ?? undefined,
        vehicleId: appointment.vehicleId ?? undefined,
        status: 'processing',
        notes: appointment.notes ?? undefined,
      },
      undefined,
      actor,
    );
    if (!order) {
      throw new BadRequestException('Не удалось создать заказ-наряд');
    }

    appointment.orderId = order.id;
    appointment.status = AppointmentStatus.IN_PROGRESS;
    await this.appointmentRepository.save(appointment);
    return this.findOne(organizationId, id);
  }

  private async findOne(organizationId: string, id: number): Promise<Appointment> {
    const appointment = await this.appointmentRepository.findOne({
      where: { id, organizationId },
      relations: ['post', 'customer', 'vehicle', 'master'],
    });
    if (!appointment) {
      throw new NotFoundException('Запись не найдена');
    }
    return this.present(appointment);
  }

  private present(appointment: Appointment): Appointment {
    if (appointment.master) {
      appointment.master.password = undefined as unknown as string;
    }
    return appointment;
  }

  private async findPost(organizationId: string, id: number): Promise<ServicePost> {
    const post = await this.postRepository.findOne({
      where: { id, organizationId, isActive: true },
    });
    if (!post) {
      throw new BadRequestException('Пост не найден');
    }
    return post;
  }

  private async ensureDefaultPosts(organizationId: string): Promise<void> {
    const count = await this.postRepository.count({ where: { organizationId } });
    if (count > 0) return;
    await this.postRepository.save([
      this.postRepository.create({
        organizationId,
        name: 'Пост 1',
        sortOrder: 0,
        isActive: true,
      }),
      this.postRepository.create({
        organizationId,
        name: 'Пост 2',
        sortOrder: 1,
        isActive: true,
      }),
    ]);
  }

  private resolveWindow(startsAtRaw: string, durationMinutes?: number) {
    const startsAt = new Date(startsAtRaw);
    if (Number.isNaN(startsAt.getTime())) {
      throw new BadRequestException('Укажите время записи');
    }
    const minutes = this.normalizeDuration(durationMinutes ?? 60);
    return {
      startsAt,
      endsAt: new Date(startsAt.getTime() + minutes * 60000),
    };
  }

  private normalizeDuration(value: number): number {
    const minutes = Number(value);
    if (!Number.isFinite(minutes) || minutes < 15 || minutes > 480) {
      throw new BadRequestException('Длительность от 15 минут до 8 часов');
    }
    return Math.round(minutes);
  }

  private async assertFree(
    postId: number,
    startsAt: Date,
    endsAt: Date,
    ignoreId?: number,
  ) {
    const query = this.appointmentRepository
      .createQueryBuilder('appointment')
      .where('appointment.postId = :postId', { postId })
      .andWhere('appointment.status IN (:...active)', { active: ACTIVE })
      .andWhere('appointment.startsAt < :endsAt', { endsAt })
      .andWhere('appointment.endsAt > :startsAt', { startsAt });
    if (ignoreId) {
      query.andWhere('appointment.id != :ignoreId', { ignoreId });
    }
    const count = await query.getCount();
    if (count > 0) {
      throw new BadRequestException('Это время на посту уже занято');
    }
  }

  private async resolveLink(
    organizationId: string,
    customerId?: number | null,
    vehicleId?: number | null,
    masterId?: string | null,
  ) {
    const normalizedCustomerId = customerId ? Number(customerId) : null;
    const normalizedVehicleId = vehicleId ? Number(vehicleId) : null;

    if (normalizedCustomerId) {
      const count = await this.customerRepository.count({
        where: { id: normalizedCustomerId, organizationId },
      });
      if (count === 0) {
        throw new BadRequestException('Клиент не найден в вашей организации');
      }
    }

    let resolvedCustomerId = normalizedCustomerId;
    if (normalizedVehicleId) {
      const vehicle = await this.vehicleRepository.findOne({
        where: { id: normalizedVehicleId, organizationId, isActive: true },
      });
      if (!vehicle) {
        throw new BadRequestException('Автомобиль не найден');
      }
      if (resolvedCustomerId && vehicle.customerId !== resolvedCustomerId) {
        throw new BadRequestException('Автомобиль принадлежит другому клиенту');
      }
      resolvedCustomerId = vehicle.customerId;
    }

    let resolvedMasterId: string | null = null;
    if (masterId) {
      const count = await this.userRepository.count({
        where: {
          id: masterId,
          organizationId,
          role: UserRole.STO,
          isActive: true,
        },
      });
      if (count === 0) {
        throw new BadRequestException('СТО не найден');
      }
      resolvedMasterId = masterId;
    }

    return {
      customerId: resolvedCustomerId,
      vehicleId: normalizedVehicleId,
      masterId: resolvedMasterId,
    };
  }
}
