import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Query,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { OrdersService } from './orders.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('api/orders')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  private async resolveOrganizationId(user: any): Promise<string | null> {
    if (user && user.organizationId) {
      return user.organizationId;
    }
    
    const orgs = await this.organizationsService.findAll();
    if (orgs.length > 0) {
      return orgs[0].id;
    }
    
    return null;
  }

  @Get('recent')
  async getRecentOrders(
    @Query('limit') limit: string = '5',
    @CurrentUser() user: any,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { orders: [] };
    }
    return this.ordersService.getRecentOrders(organizationId, parseInt(limit));
  }

  @Get()
  async findAll(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return [];
    }
    const orders = await this.ordersService.findAll(organizationId);
    return orders;
  }

  @Get('b2c')
  async getB2COrders(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return [];
    }
    return this.ordersService.findB2COrders(organizationId);
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return null;
    }
    return this.ordersService.findOne(+id, organizationId);
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async create(@CurrentUser() user: any, @Body() data: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' } as any;
    }
    return this.ordersService.create(organizationId, data, undefined, user);
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() data: any,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' } as any;
    }
    return this.ordersService.update(+id, organizationId, data, user);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async remove(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { success: false };
    }
    return this.ordersService.remove(+id, organizationId);
  }
}

