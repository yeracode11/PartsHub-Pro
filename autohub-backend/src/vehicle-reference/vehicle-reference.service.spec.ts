import { BadRequestException, ConflictException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { VehicleReferenceService } from './vehicle-reference.service';
import { VehicleMake } from './entities/vehicle-make.entity';
import { VehicleModel } from './entities/vehicle-model.entity';
import { VehicleGeneration } from './entities/vehicle-generation.entity';

describe('VehicleReferenceService', () => {
  const toyota = { id: 1, name: 'Toyota', slug: 'toyota', isActive: true, synonyms: [] };
  const camry = { id: 10, makeId: 1, name: 'Camry', slug: 'camry', isActive: true, synonyms: [] };
  const xv70 = { id: 100, modelId: 10, name: 'XV70', slug: 'xv70' };
  const x5 = { id: 20, makeId: 2, name: 'X5', slug: 'x5' };

  let service: VehicleReferenceService;
  let makes: { findOne: jest.Mock; find: jest.Mock; save: jest.Mock; create: jest.Mock };
  let models: { findOne: jest.Mock; save: jest.Mock; create: jest.Mock };
  let generations: { findOne: jest.Mock; save: jest.Mock; create: jest.Mock };

  beforeEach(async () => {
    makes = {
      findOne: jest.fn(async ({ where }) => (where.id === 1 || where.slug === 'toyota' ? toyota : null)),
      find: jest.fn(async () => []),
      create: jest.fn((data) => data),
      save: jest.fn(async (data) => ({ id: 3, ...data })),
    };
    models = {
      findOne: jest.fn(async ({ where }) => {
        if (where.id === 10) return camry;
        if (where.id === 20) return x5;
        if (where.slug === 'camry' && where.makeId === 1) return camry;
        return null;
      }),
      create: jest.fn((data) => data),
      save: jest.fn(async (data) => data),
    };
    generations = {
      findOne: jest.fn(async ({ where }) => (where.id === 100 ? xv70 : null)),
      create: jest.fn((data) => data),
      save: jest.fn(async (data) => data),
    };
    const moduleRef = await Test.createTestingModule({
      providers: [
        VehicleReferenceService,
        { provide: getRepositoryToken(VehicleMake), useValue: makes },
        { provide: getRepositoryToken(VehicleModel), useValue: models },
        { provide: getRepositoryToken(VehicleGeneration), useValue: generations },
      ],
    }).compile();
    service = moduleRef.get(VehicleReferenceService);
  });

  it('не связывает модель чужой марки', async () => {
    await expect(service.resolveLink(1, 20)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('не связывает поколение чужой модели', async () => {
    await expect(service.resolveLink(1, 10, 999)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('принимает Toyota → Camry → XV70', async () => {
    await expect(service.resolveLink(1, 10, 100)).resolves.toMatchObject({
      make: 'Toyota',
      model: 'Camry',
      generation: 'XV70',
    });
  });

  it('не создаёт вторую Toyota', async () => {
    await expect(service.createMake('Toyota')).rejects.toBeInstanceOf(ConflictException);
  });

  it('не создаёт вторую Camry у Toyota', async () => {
    await expect(service.createModel(1, 'Camry')).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
