import { NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Test, TestingModule } from '@nestjs/testing';
import { OrganizationsController } from './organizations.controller';
import { OrganizationsService } from './organizations.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UserRole } from '../common/enums/user-role.enum';

describe('OrganizationsController', () => {
  let controller: OrganizationsController;
  const service = {
    create: jest.fn(),
    findAll: jest.fn(),
    findByBusinessType: jest.fn(),
    findOne: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
  };
  const ownerA = { id: 'u-a', organizationId: 'org-a', role: UserRole.OWNER };
  const superadmin = {
    id: 'u-s',
    organizationId: null,
    role: UserRole.SUPERADMIN,
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [OrganizationsController],
      providers: [{ provide: OrganizationsService, useValue: service }],
    }).compile();

    controller = module.get<OrganizationsController>(OrganizationsController);
  });

  it('requires JWT on every route', () => {
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      OrganizationsController,
    );
    expect(guards).toContain(JwtAuthGuard);
  });

  it('restricts create, list and delete to superadmin', () => {
    for (const method of ['create', 'findAll', 'remove'] as const) {
      const roles = Reflect.getMetadata(
        'roles',
        OrganizationsController.prototype[method],
      );
      expect(roles).toEqual([UserRole.SUPERADMIN]);
    }
  });

  it('hides another organization from an owner', () => {
    expect(() => controller.findOne(ownerA, 'org-b')).toThrow(
      NotFoundException,
    );
    expect(() => controller.update(ownerA, 'org-b', { name: 'x' })).toThrow(
      NotFoundException,
    );
    expect(service.findOne).not.toHaveBeenCalled();
    expect(service.update).not.toHaveBeenCalled();
  });

  it('lets an owner edit only safe fields of own organization', () => {
    controller.update(ownerA, 'org-a', {
      name: 'New',
      isActive: false,
      businessType: 'parts' as never,
      settings: { x: 1 },
    });
    expect(service.update).toHaveBeenCalledWith('org-a', { name: 'New' });
  });

  it('lets superadmin access any organization', () => {
    controller.findOne(superadmin, 'org-b');
    expect(service.findOne).toHaveBeenCalledWith('org-b');
  });
});
