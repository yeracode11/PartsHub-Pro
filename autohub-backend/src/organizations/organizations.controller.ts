import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  NotFoundException,
} from '@nestjs/common';
import { OrganizationsService } from './organizations.service';
import { CreateOrganizationDto } from './dto/create-organization.dto';
import { UpdateOrganizationDto } from './dto/update-organization.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';

const OWNER_EDITABLE_FIELDS = ['name', 'phone', 'address'] as const;

type RequestUser = { role?: UserRole; organizationId?: string | null };

@Controller('api/organizations')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrganizationsController {
  constructor(private readonly organizationsService: OrganizationsService) {}

  @Post()
  @Roles(UserRole.SUPERADMIN)
  create(@Body() createDto: CreateOrganizationDto) {
    return this.organizationsService.create(createDto);
  }

  @Get()
  @Roles(UserRole.SUPERADMIN)
  findAll(@Query('businessType') businessType?: string) {
    if (businessType) {
      return this.organizationsService.findByBusinessType(businessType);
    }
    return this.organizationsService.findAll();
  }

  @Get(':id')
  findOne(@CurrentUser() user: RequestUser, @Param('id') id: string) {
    this.assertAccess(user, id);
    return this.organizationsService.findOne(id);
  }

  @Put(':id')
  @Roles(UserRole.SUPERADMIN, UserRole.OWNER)
  update(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() updateDto: UpdateOrganizationDto,
  ) {
    this.assertAccess(user, id);
    if (user.role === UserRole.SUPERADMIN) {
      return this.organizationsService.update(id, updateDto);
    }
    const allowed: UpdateOrganizationDto = {};
    for (const field of OWNER_EDITABLE_FIELDS) {
      if (updateDto?.[field] !== undefined) {
        allowed[field] = updateDto[field];
      }
    }
    return this.organizationsService.update(id, allowed);
  }

  @Delete(':id')
  @Roles(UserRole.SUPERADMIN)
  remove(@Param('id') id: string) {
    return this.organizationsService.remove(id);
  }

  private assertAccess(user: RequestUser, organizationId: string) {
    if (user?.role === UserRole.SUPERADMIN) return;
    if (!user?.organizationId || user.organizationId !== organizationId) {
      throw new NotFoundException(
        `Organization with ID ${organizationId} not found`,
      );
    }
  }
}
