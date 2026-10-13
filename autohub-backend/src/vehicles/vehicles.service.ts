import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import { Vehicle } from './entities/vehicle.entity';
import { VehicleServiceRecord } from './entities/vehicle-service-record.entity';
import { Customer } from '../customers/entities/customer.entity';
import { businessToday } from '../donors/donor-status';

export interface RecordServiceInput {
  mileage: number;
  serviceDate?: string | Date;
  description?: string | null;
  orderId?: number | null;
  nextServiceMileage?: number | null;
  nextServiceDate?: string | Date | null;
}

/** Целое неотрицательное число или ошибка 400. */
function mileageValue(value: unknown, field: string): number {
  const number = Number(value);
  if (value === null || value === undefined || value === '' || !Number.isInteger(number) || number < 0) {
    throw new BadRequestException(`${field}: укажите целое неотрицательное число`);
  }
  return number;
}

/** Дата 'YYYY-MM-DD' из строки или Date; пустое — null. */
function dateValue(value: unknown, field: string): string | null {
  if (value === null || value === undefined || value === '') return null;
  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) {
    throw new BadRequestException(`${field}: неверная дата`);
  }
  return /^\d{4}-\d{2}-\d{2}$/.test(String(value))
    ? String(value)
    : businessToday(date);
}

const IMMUTABLE_FIELDS = ['id', 'organizationId', 'createdAt', 'updatedAt'];

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(Vehicle)
    private readonly vehicleRepository: Repository<Vehicle>,
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
    @InjectRepository(VehicleServiceRecord)
    private readonly serviceRecordRepository: Repository<VehicleServiceRecord>,
  ) {}

  /** Госномер и VIN храним в одном виде, иначе «123 ABC 02» и «123abc02» станут разными машинами. */
  static normalizePlate(value?: string | null): string | undefined {
    if (value == null) return undefined;
    return value.replace(/\s+/g, '').toUpperCase();
  }

  static normalizeVin(value?: string | null): string | null | undefined {
    if (value === undefined) return undefined;
    if (value === null) return null;
    const vin = value.replace(/\s+/g, '').toUpperCase();
    return vin.length ? vin : null;
  }

  private sanitize(data: Partial<Vehicle>): Partial<Vehicle> {
    const clean: Partial<Vehicle> = { ...data };
    for (const key of IMMUTABLE_FIELDS) delete (clean as any)[key];
    delete (clean as any).customer;
    delete (clean as any).orders;
    delete (clean as any).organization;

    if (clean.plateNumber !== undefined) {
      clean.plateNumber = VehiclesService.normalizePlate(clean.plateNumber)!;
      if (!clean.plateNumber) {
        throw new BadRequestException('Укажите госномер автомобиля');
      }
    }
    if (clean.vin !== undefined) {
      clean.vin = VehiclesService.normalizeVin(clean.vin) as string;
      if (clean.vin && clean.vin.length !== 17) {
        throw new BadRequestException('VIN должен содержать 17 символов');
      }
    }
    return clean;
  }

  private async assertCustomerInOrganization(
    customerId: number | undefined,
    organizationId: string,
  ) {
    if (customerId == null) return;
    const count = await this.customerRepository.count({
      where: { id: customerId, organizationId },
    });
    if (count === 0) {
      throw new BadRequestException('Владелец не найден в вашей организации');
    }
  }

  private async assertUnique(
    organizationId: string,
    data: Partial<Vehicle>,
    excludeId?: number,
  ) {
    const idFilter = excludeId ? { id: Not(excludeId) } : {};
    if (data.plateNumber) {
      const duplicate = await this.vehicleRepository.findOne({
        where: {
          organizationId,
          plateNumber: data.plateNumber,
          isActive: true,
          ...idFilter,
        },
        relations: ['customer'],
      });
      if (duplicate) {
        throw new ConflictException(
          `Автомобиль с госномером ${data.plateNumber} уже есть у клиента «${duplicate.customer?.name ?? '—'}». Смените владельца в карточке автомобиля.`,
        );
      }
    }
    if (data.vin) {
      const duplicate = await this.vehicleRepository.findOne({
        where: { organizationId, vin: data.vin, isActive: true, ...idFilter },
        relations: ['customer'],
      });
      if (duplicate) {
        throw new ConflictException(
          `Автомобиль с VIN ${data.vin} уже есть у клиента «${duplicate.customer?.name ?? '—'}».`,
        );
      }
    }
  }

  /**
   * Получить все автомобили организации
   */
  async findAll(organizationId: string) {
    return await this.vehicleRepository.find({
      where: { organizationId, isActive: true },
      relations: ['customer'],
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Получить автомобили конкретного клиента
   */
  async findByCustomer(organizationId: string, customerId: number) {
    return await this.vehicleRepository.find({
      where: { organizationId, customerId, isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Получить один автомобиль
   */
  async findOne(id: number, organizationId: string) {
    const vehicle = await this.vehicleRepository.findOne({
      where: { id, organizationId },
      relations: ['customer', 'orders', 'orders.items', 'orders.items.item'],
    });

    if (!vehicle) {
      throw new NotFoundException(`Автомобиль #${id} не найден`);
    }

    if (vehicle.orders) {
      vehicle.orders.sort(
        (a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      );
    }

    return vehicle;
  }

  /**
   * Создать новый автомобиль
   */
  async create(organizationId: string, data: Partial<Vehicle>) {
    const clean = this.sanitize(data);
    if (!clean.customerId) {
      throw new BadRequestException('Выберите владельца автомобиля');
    }
    if (!clean.plateNumber) {
      throw new BadRequestException('Укажите госномер автомобиля');
    }
    await this.assertCustomerInOrganization(clean.customerId, organizationId);
    await this.assertUnique(organizationId, clean);

    const vehicle = this.vehicleRepository.create({
      ...clean,
      organizationId,
      isActive: true,
    });

    const saved = await this.vehicleRepository.save(vehicle);
    return await this.findOne(saved.id, organizationId);
  }

  /**
   * Обновить автомобиль
   */
  async update(
    id: number,
    organizationId: string,
    data: Partial<Vehicle>,
  ) {
    await this.findOne(id, organizationId); // Проверка существования

    const clean = this.sanitize(data);
    delete clean.isActive;
    await this.assertCustomerInOrganization(clean.customerId, organizationId);
    await this.assertUnique(organizationId, clean, id);

    if (Object.keys(clean).length > 0) {
      await this.vehicleRepository.update({ id, organizationId }, clean);
    }

    return await this.findOne(id, organizationId);
  }

  /**
   * Удалить автомобиль (мягкое удаление)
   */
  async remove(id: number, organizationId: string) {
    await this.findOne(id, organizationId); // Проверка существования

    await this.vehicleRepository.update(
      { id, organizationId },
      { isActive: false },
    );

    return { success: true };
  }

  /**
   * Обновить пробег. Пробег не уменьшается: ошибочно введённое значение
   * исправляется в форме автомобиля.
   */
  async updateMileage(
    id: number,
    organizationId: string,
    mileage: unknown,
  ) {
    const vehicle = await this.findOne(id, organizationId);
    const value = mileageValue(mileage, 'Пробег');
    if (value < (vehicle.currentMileage ?? 0)) {
      throw new BadRequestException(
        `Пробег не может быть меньше текущего (${vehicle.currentMileage} км)`,
      );
    }

    await this.vehicleRepository.update(
      { id, organizationId },
      { currentMileage: value },
    );

    return await this.findOne(id, organizationId);
  }

  /**
   * Записать ТО: новая строка сервисной истории + обновление «последнее/следующее ТО»
   * у автомобиля, в одной транзакции.
   */
  async recordService(
    id: number,
    organizationId: string,
    data: RecordServiceInput,
    userId?: string | null,
  ) {
    const vehicle = await this.findOne(id, organizationId);

    const mileage = mileageValue(data.mileage, 'Пробег при ТО');
    const serviceDate = dateValue(data.serviceDate, 'Дата ТО') ?? businessToday();
    if (serviceDate > businessToday()) {
      throw new BadRequestException('Дата ТО не может быть в будущем');
    }
    const nextServiceMileage =
      data.nextServiceMileage === null || data.nextServiceMileage === undefined || (data.nextServiceMileage as unknown) === ''
        ? null
        : mileageValue(data.nextServiceMileage, 'Следующее ТО по пробегу');
    if (nextServiceMileage !== null && nextServiceMileage <= mileage) {
      throw new BadRequestException('Следующее ТО по пробегу должно быть больше пробега при ТО');
    }
    const nextServiceDate = dateValue(data.nextServiceDate, 'Следующее ТО по дате');
    if (nextServiceDate !== null && nextServiceDate <= serviceDate) {
      throw new BadRequestException('Дата следующего ТО должна быть позже даты ТО');
    }
    const description = data.description?.toString().trim() || null;
    const orderId = data.orderId ? Number(data.orderId) : null;

    await this.vehicleRepository.manager.transaction(async (manager) => {
      await manager.getRepository(VehicleServiceRecord).save(
        manager.getRepository(VehicleServiceRecord).create({
          organizationId,
          vehicleId: id,
          serviceDate,
          mileage,
          description,
          orderId,
          nextServiceMileage,
          nextServiceDate,
          createdById: userId ?? null,
        }),
      );

      // Запись задним числом не должна откатывать актуальные данные машины.
      const isLatest =
        !vehicle.lastServiceDate || serviceDate >= dateValue(vehicle.lastServiceDate, 'lastServiceDate')!;
      const patch: Partial<Vehicle> = {
        currentMileage: Math.max(vehicle.currentMileage ?? 0, mileage),
      };
      if (isLatest) {
        Object.assign(patch, {
          lastServiceMileage: mileage,
          lastServiceDate: serviceDate,
          nextServiceMileage,
          nextServiceDate,
        });
      }
      await manager.getRepository(Vehicle).update({ id, organizationId }, patch as any);
    });

    return await this.findOne(id, organizationId);
  }

  /** Сервисная история автомобиля, новые записи сверху. */
  async getServiceHistory(id: number, organizationId: string) {
    await this.findOne(id, organizationId);
    return this.serviceRecordRepository.find({
      where: { vehicleId: id, organizationId },
      order: { serviceDate: 'DESC', id: 'DESC' },
    });
  }

  /**
   * Получить автомобили, которым скоро нужно ТО
   */
  async getUpcomingService(organizationId: string) {
    const vehicles = await this.vehicleRepository.find({
      where: { organizationId, isActive: true },
      relations: ['customer'],
    });

    const now = new Date();
    const inTwoWeeks = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

    return vehicles.filter((vehicle) => {
      // Проверка по дате
      if (vehicle.nextServiceDate) {
        const serviceDate = new Date(vehicle.nextServiceDate);
        if (serviceDate <= inTwoWeeks) {
          return true;
        }
      }

      // Проверка по пробегу (если осталось менее 1000 км)
      if (
        vehicle.nextServiceMileage &&
        vehicle.currentMileage &&
        vehicle.nextServiceMileage - vehicle.currentMileage <= 1000
      ) {
        return true;
      }

      return false;
    });
  }

  /**
   * Поиск по госномеру или VIN
   */
  async search(organizationId: string, query: string) {
    const vehicles = await this.vehicleRepository
      .createQueryBuilder('vehicle')
      .leftJoinAndSelect('vehicle.customer', 'customer')
      .where('vehicle.organizationId = :organizationId', { organizationId })
      .andWhere('vehicle.isActive = :isActive', { isActive: true })
      .andWhere(
        '(LOWER(vehicle.plateNumber) LIKE LOWER(:query) OR LOWER(vehicle.vin) LIKE LOWER(:query) OR LOWER(vehicle.brand) LIKE LOWER(:query) OR LOWER(vehicle.model) LIKE LOWER(:query))',
        { query: `%${query}%` },
      )
      .getMany();

    return vehicles;
  }
}

