import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UserRole } from '../common/enums/user-role.enum';

describe('UsersController', () => {
  let controller: UsersController;
  const service = {
    create: jest.fn(),
    createOrUpdate: jest.fn(),
    findByFirebaseUid: jest.fn(),
    findAll: jest.fn(),
    findByOrganization: jest.fn(),
    findOne: jest.fn(),
  };
  const ownerA = { id: 'u-a', organizationId: 'org-a', role: UserRole.OWNER };
  const workerA = { id: 'w-a', organizationId: 'org-a', role: UserRole.WORKER };
  const superadmin = {
    id: 'u-s',
    organizationId: null,
    role: UserRole.SUPERADMIN,
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [{ provide: UsersService, useValue: service }],
    }).compile();

    controller = module.get<UsersController>(UsersController);
  });

  it('protects legacy routes with JWT and superadmin role', () => {
    for (const method of [
      'create',
      'createOrUpdate',
      'findByFirebaseUid',
    ] as const) {
      const handler = UsersController.prototype[method];
      expect(Reflect.getMetadata(GUARDS_METADATA, handler)).toContain(
        JwtAuthGuard,
      );
      expect(Reflect.getMetadata('roles', handler)).toEqual([
        UserRole.SUPERADMIN,
      ]);
    }
    for (const method of ['findByOrganization', 'findOne'] as const) {
      const handler = UsersController.prototype[method];
      expect(Reflect.getMetadata(GUARDS_METADATA, handler)).toContain(
        JwtAuthGuard,
      );
    }
  });

  it('lists only own organization for an owner', async () => {
    await controller.findAll(ownerA);
    expect(service.findByOrganization).toHaveBeenCalledWith('org-a');
    expect(service.findAll).not.toHaveBeenCalled();
  });

  it('lists everyone for superadmin', async () => {
    await controller.findAll(superadmin);
    expect(service.findAll).toHaveBeenCalled();
  });

  it('forbids reading staff of another organization', () => {
    expect(() => controller.findByOrganization(workerA, 'org-b')).toThrow(
      ForbiddenException,
    );
    controller.findByOrganization(workerA, 'org-a');
    expect(service.findByOrganization).toHaveBeenCalledWith('org-a');
  });

  it('hides a user from another organization', async () => {
    service.findOne.mockResolvedValue({ id: 'u-b', organizationId: 'org-b' });
    await expect(controller.findOne(ownerA, 'u-b')).rejects.toThrow(
      NotFoundException,
    );
    await expect(controller.findOne(superadmin, 'u-b')).resolves.toMatchObject({
      id: 'u-b',
    });
  });
});
