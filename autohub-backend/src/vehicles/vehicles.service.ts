import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Vehicle } from './entities/vehicle.entity';

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(Vehicle)
    private readonly vehicleRepository: Repository<Vehicle>,
  ) {}

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
      throw new Error(`Vehicle with ID ${id} not found`);
    }

    return vehicle;
  }

  /**
   * Создать новый автомобиль
   */
  async create(organizationId: string, data: Partial<Vehicle>) {
    const vehicle = this.vehicleRepository.create({
      ...data,
      organizationId,
    });

    return await this.vehicleRepository.save(vehicle);
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

    await this.vehicleRepository.update({ id, organizationId }, data);

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

