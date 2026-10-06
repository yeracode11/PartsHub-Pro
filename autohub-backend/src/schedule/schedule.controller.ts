import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ScheduleService, CreateAppointmentInput, UpdateAppointmentInput } from './schedule.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { OrganizationsService } from '../organizations/organizations.service';

class PostNameBody {
  name: string;
}

@Controller('api/schedule')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ScheduleController {
  constructor(
    private readonly scheduleService: ScheduleService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  private async resolveOrganizationId(user: any): Promise<string | null> {
    if (user?.organizationId) return user.organizationId;
    const orgs = await this.organizationsService.findAll();
    return orgs.length > 0 ? orgs[0].id : null;
  }

  @Get('posts')
  async posts(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return [];
    return this.scheduleService.listPosts(organizationId);
  }

  @Post('posts')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async createPost(@CurrentUser() user: any, @Body() body: PostNameBody) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return { error: 'No active organization' };
    return this.scheduleService.createPost(organizationId, body?.name);
  }

  @Patch('posts/:id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async renamePost(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: PostNameBody,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return { error: 'No active organization' };
    return this.scheduleService.renamePost(organizationId, +id, body?.name);
  }

  @Delete('posts/:id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async removePost(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return { success: false };
    await this.scheduleService.removePost(organizationId, +id);
    return { success: true };
  }

  @Get('masters')
  async masters(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return [];
    return this.scheduleService.listMasters(organizationId);
  }

  @Get('appointments')
  async appointments(
    @CurrentUser() user: any,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return [];
    const start = new Date(from);
    const end = new Date(to);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      return [];
    }
    const masterId = user?.role === UserRole.WORKER ? user.id : undefined;
    return this.scheduleService.listAppointments(
      organizationId,
      start,
      end,
      masterId,
    );
  }

  @Post('appointments')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async createAppointment(
    @CurrentUser() user: any,
    @Body() body: CreateAppointmentInput,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return { error: 'No active organization' };
    return this.scheduleService.createAppointment(organizationId, body);
  }

  @Patch('appointments/:id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async updateAppointment(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: UpdateAppointmentInput,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return { error: 'No active organization' };
    return this.scheduleService.updateAppointment(organizationId, +id, body);
  }

  @Post('appointments/:id/order')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async createOrder(
    @Param('id') id: string,
    @CurrentUser() user: any,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) return { error: 'No active organization' };
    return this.scheduleService.createOrder(organizationId, +id, user);
  }
}
