import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { WorksService, WorkCatalogInput } from './works.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('api/works')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WorksController {
  constructor(
    private readonly worksService: WorksService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  /**
   * Только организация из JWT. Раньше без неё подставлялась первая организация в БД —
   * пользователь без организации получал доступ к чужим данным.
   */
  private async resolveOrganizationId(user: any): Promise<string | null> {
    return user?.organizationId ?? null;
  }

  @Get()
  async findAll(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return [];
    }
    return this.worksService.findCatalog(organizationId);
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STO)
  async create(@CurrentUser() user: any, @Body() data: WorkCatalogInput) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' };
    }
    return this.worksService.createCatalog(organizationId, data);
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STO)
  async update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() data: WorkCatalogInput,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' };
    }
    return this.worksService.updateCatalog(+id, organizationId, data);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STO)
  async remove(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { success: false };
    }
    await this.worksService.removeCatalog(+id, organizationId);
    return { success: true };
  }
}
