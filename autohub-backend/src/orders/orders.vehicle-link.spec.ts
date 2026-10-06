import { BadRequestException } from '@nestjs/common';
import { OrdersService } from './orders.service';

describe('OrdersService.resolveCustomerAndVehicle', () => {
  const vehicleRepository = { findOne: jest.fn() };
  const customerRepository = { count: jest.fn() };
  const service = new OrdersService(
    {} as any,
    vehicleRepository as any,
    customerRepository as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );

  beforeEach(() => jest.resetAllMocks());

  it('allows a walk-in order without customer and vehicle', async () => {
    await expect(
      service.resolveCustomerAndVehicle('org-1', null, null),
    ).resolves.toEqual({ customerId: null, vehicleId: null });
  });

  it('takes the customer from the vehicle owner when only a vehicle is given', async () => {
    vehicleRepository.findOne.mockResolvedValue({ id: 7, customerId: 3 });

    await expect(
      service.resolveCustomerAndVehicle('org-1', undefined, 7),
    ).resolves.toEqual({ customerId: 3, vehicleId: 7 });
    expect(vehicleRepository.findOne).toHaveBeenCalledWith({
      where: { id: 7, organizationId: 'org-1', isActive: true },
    });
  });

  it('rejects a vehicle that belongs to another customer', async () => {
    customerRepository.count.mockResolvedValue(1);
    vehicleRepository.findOne.mockResolvedValue({ id: 7, customerId: 3 });

    await expect(
      service.resolveCustomerAndVehicle('org-1', 5, 7),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a customer from another organization', async () => {
    customerRepository.count.mockResolvedValue(0);

    await expect(
      service.resolveCustomerAndVehicle('org-1', 99, null),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a vehicle from another organization', async () => {
    vehicleRepository.findOne.mockResolvedValue(null);

    await expect(
      service.resolveCustomerAndVehicle('org-1', null, 42),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
