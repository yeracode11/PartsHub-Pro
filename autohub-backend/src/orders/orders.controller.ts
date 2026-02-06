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
    console.log('🔍 resolveOrganizationId called');
    console.log('   user:', JSON.stringify(user, null, 2));
    console.log('   user.organizationId:', user?.organizationId);
    console.log('   user.organizationId type:', typeof user?.organizationId);
    
    if (user && user.organizationId) {
      console.log('   ✅ Using user.organizationId:', user.organizationId);
      return user.organizationId;
    }
    
    console.log('   ⚠️ User organizationId not found, searching for organizations...');
    const orgs = await this.organizationsService.findAll();
    console.log(`   Found ${orgs.length} organizations`);
    if (orgs.length > 0) {
      console.log('   Using first organization:', orgs[0].id);
      return orgs[0].id;
    }
    
    console.log('   ❌ No organizations found');
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
    console.log('📦 OrdersController.findAll called');
    console.log('   User:', JSON.stringify(user, null, 2));
    const organizationId = await this.resolveOrganizationId(user);
    console.log('   Resolved organizationId:', organizationId);
    if (!organizationId) {
      console.log('   ⚠️ No organizationId found, returning empty array');
      return [];
    }
    const orders = await this.ordersService.findAll(organizationId);
    console.log(`   ✅ Returning ${orders.length} orders`);
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

  // Временный endpoint для отладки - показывает все заказы
  @Get('debug/all')
  async getAllOrdersDebug(@CurrentUser() user: any) {
    console.log('🔍 DEBUG: getAllOrdersDebug called');
    const organizationId = await this.resolveOrganizationId(user);
    console.log('   User organizationId:', organizationId);
    
    // Получаем все заказы из базы
    const allOrders = await this.ordersService.findAllForDebug();
    
    console.log(`   Total orders in DB: ${allOrders.length}`);
    
    return {
      userOrganizationId: organizationId,
      totalOrders: allOrders.length,
      orders: allOrders.map(order => ({
        id: order.id,
        orderNumber: order.orderNumber,
        organizationId: order.organizationId,
        organizationName: order.organization?.name,
        isB2C: order.isB2C,
        status: order.status,
        totalAmount: order.totalAmount,
        createdAt: order.createdAt,
        itemsCount: order.items?.length || 0,
      })),
    };
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
    return this.ordersService.create(organizationId, data);
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

