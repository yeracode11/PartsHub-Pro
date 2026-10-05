import { BadRequestException, ConflictException } from '@nestjs/common';
import { VehiclesService } from './vehicles.service';

describe('VehiclesService', () => {
  const vehicleRepository = {
    findOne: jest.fn(),
    create: jest.fn((v) => v),
    save: jest.fn(),
    update: jest.fn(),
  };
  const customerRepository = { count: jest.fn() };
  const service = new VehiclesService(
    vehicleRepository as any,
    customerRepository as any,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    vehicleRepository.create.mockImplementation((v) => v);
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
});
