import { BadRequestException } from '@nestjs/common';
import { WorksService } from './works.service';

describe('WorksService', () => {
  const catalogRepository: any = {
    findOne: jest.fn(),
  };
  const orderWorkRepository: any = {
    delete: jest.fn().mockResolvedValue(undefined),
    create: jest.fn((data) => data),
    save: jest.fn((data) => Promise.resolve(data)),
    find: jest.fn(),
  };
  const userRepository: any = {
    count: jest.fn(),
  };

  const service = new WorksService(
    catalogRepository,
    orderWorkRepository,
    userRepository,
  );

  beforeEach(() => jest.clearAllMocks());

  it('snapshots catalog values and computes subtotal', async () => {
    catalogRepository.findOne.mockResolvedValue({
      id: 4,
      name: 'Замена масла',
      normHours: 0.5,
      pricePerHour: 8000,
    });
    userRepository.count.mockResolvedValue(1);

    const total = await service.replaceOrderWorks(1, 'org-1', [
      { workCatalogId: 4, performerId: 'user-1' },
    ]);

    expect(total).toBe(4000);
    expect(orderWorkRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        orderId: 1,
        name: 'Замена масла',
        subtotal: 4000,
        performerId: 'user-1',
      }),
    );
  });

  it('rejects a performer from another organization', async () => {
    catalogRepository.findOne.mockResolvedValue({
      id: 4,
      name: 'Замена масла',
      normHours: 1,
      pricePerHour: 1000,
    });
    userRepository.count.mockResolvedValue(0);

    await expect(
      service.replaceOrderWorks(1, 'org-1', [
        { workCatalogId: 4, performerId: 'stranger' },
      ]),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('requires a name for a custom work', async () => {
    await expect(
      service.replaceOrderWorks(1, 'org-1', [{ name: '   ' }]),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
