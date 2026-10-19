import { BadRequestException, ConflictException } from '@nestjs/common';
import { VehiclesService } from './vehicles.service';

describe('VehiclesService', () => {
  // Транзакция: менеджер отдаёт те же моки репозиториев.
  const txRecords = { create: jest.fn((v) => v), save: jest.fn() };
  const txVehicles = { update: jest.fn() };
  const manager = {
    transaction: jest.fn(async (work: any) => work(manager)),
    getRepository: jest.fn((entity: any) =>
      entity.name === 'VehicleServiceRecord' ? txRecords : txVehicles,
    ),
  };
  const vehicleRepository = {
    findOne: jest.fn(),
    create: jest.fn((v) => v),
    save: jest.fn(),
    update: jest.fn(),
    manager,
  };
  const customerRepository = { count: jest.fn() };
  const serviceRecordRepository = { find: jest.fn() };
  const service = new VehiclesService(
    vehicleRepository as any,
    customerRepository as any,
    serviceRecordRepository as any,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    vehicleRepository.create.mockImplementation((v) => v);
  });

  it('escapes LIKE wildcards in user input', () => {
    expect(VehiclesService.escapeLike('50%_a\\b')).toBe('50\\%\\_a\\\\b');
  });

  describe('findAll', () => {
    const makeQuery = () => {
      const query: any = {};
      for (const name of [
        'leftJoinAndSelect',
        'where',
        'andWhere',
        'orderBy',
        'addOrderBy',
        'take',
        'skip',
      ]) {
        query[name] = jest.fn().mockReturnValue(query);
      }
      query.getMany = jest.fn().mockResolvedValue([]);
      return query;
    };

    it('returns everything of the organization without options', async () => {
      const query = makeQuery();
      (vehicleRepository as any).createQueryBuilder = jest.fn(() => query);
      await service.findAll('org');
      expect(query.where).toHaveBeenCalledWith(
        'vehicle.organizationId = :organizationId',
        { organizationId: 'org' },
      );
      expect(query.take).not.toHaveBeenCalled();
      expect(query.andWhere).toHaveBeenCalledTimes(1); // только isActive
    });

    it('filters by escaped query and pages', async () => {
      const query = makeQuery();
      (vehicleRepository as any).createQueryBuilder = jest.fn(() => query);
      await service.findAll('org', { q: ' 123 ab% ', limit: 50, offset: 100 });
      const [, params] = query.andWhere.mock.calls[1];
      expect(params.plate).toBe('%123AB\\%%');
      expect(params.text).toBe('%123 ab\\%%');
      expect(query.take).toHaveBeenCalledWith(50);
      expect(query.skip).toHaveBeenCalledWith(100);
    });
  });

  it('normalizes plate number and VIN', () => {
    expect(VehiclesService.normalizePlate(' 123 abc 02 ')).toBe('123ABC02');
    expect(VehiclesService.normalizeVin(' jtdbe32k123456789 ')).toBe(
      'JTDBE32K123456789',
    );
    expect(VehiclesService.normalizeVin('  ')).toBeNull();
  });

  it('refuses to attach a vehicle to a customer of another organization', async () => {
    customerRepository.count.mockResolvedValue(0);

    await expect(
      service.create('org-1', { customerId: 5, plateNumber: '123ABC02' } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(vehicleRepository.save).not.toHaveBeenCalled();
  });

  it('reports a duplicate plate inside the organization as a conflict', async () => {
    customerRepository.count.mockResolvedValue(1);
    vehicleRepository.findOne.mockResolvedValueOnce({
      id: 1,
      customer: { name: 'Арман' },
    });

    await expect(
      service.create('org-1', { customerId: 5, plateNumber: '123 abc 02' } as any),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(vehicleRepository.findOne).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organizationId: 'org-1',
          plateNumber: '123ABC02',
          isActive: true,
        }),
      }),
    );
  });

  it('rejects a VIN that is not 17 characters', async () => {
    await expect(
      service.create('org-1', {
        customerId: 5,
        plateNumber: '123ABC02',
        vin: 'SHORT',
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('ignores organizationId sent by the client on update', async () => {
    vehicleRepository.findOne.mockResolvedValue({ id: 1, orders: [] });
    customerRepository.count.mockResolvedValue(1);

    await service.update(1, 'org-1', {
      organizationId: 'org-evil',
      color: 'Белый',
    } as any);

    expect(vehicleRepository.update).toHaveBeenCalledWith(
      { id: 1, organizationId: 'org-1' },
      { color: 'Белый' },
    );
  });

  describe('mileage and service history', () => {
    const vehicle = {
      id: 7,
      organizationId: 'org-1',
      currentMileage: 100000,
      lastServiceDate: '2026-06-01',
      lastServiceMileage: 95000,
    };

    beforeEach(() => {
      vehicleRepository.findOne.mockResolvedValue({ ...vehicle });
    });

    it('rejects mileage lower than current and negative values', async () => {
      await expect(service.updateMileage(7, 'org-1', 90000)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      await expect(service.updateMileage(7, 'org-1', -5)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(vehicleRepository.update).not.toHaveBeenCalled();
    });

    it('records service into history and updates the vehicle cache', async () => {
      await service.recordService(
        7,
        'org-1',
        {
          mileage: 105000,
          serviceDate: '2026-10-01',
          description: ' Замена масла ',
          nextServiceMileage: 115000,
          nextServiceDate: '2027-04-01',
        },
        'user-1',
      );

      expect(txRecords.save).toHaveBeenCalledWith(
        expect.objectContaining({
          organizationId: 'org-1',
          vehicleId: 7,
          mileage: 105000,
          serviceDate: '2026-10-01',
          description: 'Замена масла',
          createdById: 'user-1',
        }),
      );
      expect(txVehicles.update).toHaveBeenCalledWith(
        { id: 7, organizationId: 'org-1' },
        expect.objectContaining({
          currentMileage: 105000,
          lastServiceMileage: 105000,
          lastServiceDate: '2026-10-01',
          nextServiceMileage: 115000,
        }),
      );
    });

    it('back-dated service does not roll back mileage or last service', async () => {
      await service.recordService(7, 'org-1', {
        mileage: 80000,
        serviceDate: '2025-12-01',
      });

      expect(txRecords.save).toHaveBeenCalled();
      const patch = txVehicles.update.mock.calls[0][1];
      expect(patch).toEqual({ currentMileage: 100000 });
    });

    it('validates next service against the service itself', async () => {
      await expect(
        service.recordService(7, 'org-1', {
          mileage: 105000,
          serviceDate: '2026-10-01',
          nextServiceMileage: 104000,
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.recordService(7, 'org-1', {
          mileage: 105000,
          serviceDate: '2026-10-01',
          nextServiceDate: '2026-09-01',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(txRecords.save).not.toHaveBeenCalled();
    });
  });
});
