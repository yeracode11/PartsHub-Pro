import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import { Vehicle } from './entities/vehicle.entity';
import { Customer } from '../customers/entities/customer.entity';

const IMMUTABLE_FIELDS = ['id', 'organizationId', 'createdAt', 'updatedAt'];

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(Vehicle)
    private readonly vehicleRepository: Repository<Vehicle>,
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
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
   * Обновить пробег
   */
  async updateMileage(
    id: number,
    organizationId: string,
    mileage: number,
  ) {
    await this.findOne(id, organizationId);

    await this.vehicleRepository.update(
      { id, organizationId },
      { currentMileage: mileage },
    );

    return await this.findOne(id, organizationId);
  }

  /**
   * Записать ТО (техническое обслуживание)
   */
  async recordService(
    id: number,
    organizationId: string,
    data: {
      mileage: number;
      serviceDate: Date;
      nextServiceMileage?: number;
      nextServiceDate?: Date;
    },
  ) {
    await this.findOne(id, organizationId);

    await this.vehicleRepository.update(
      { id, organizationId },
      {
        lastServiceMileage: data.mileage,
        lastServiceDate: data.serviceDate,
        currentMileage: data.mileage,
        nextServiceMileage: data.nextServiceMileage,
        nextServiceDate: data.nextServiceDate,
      },
    );

    return await this.findOne(id, organizationId);
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

