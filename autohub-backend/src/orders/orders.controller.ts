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
import { SaleReturnsService } from './sale-returns.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { OrganizationsService } from '../organizations/organizations.service';

class PaymentBody {
  amount?: number;
  method?: string;
  idempotencyKey?: string;
}

@Controller('api/orders')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
    private readonly organizationsService: OrganizationsService,
    private readonly saleReturnsService: SaleReturnsService,
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

  @Get('payments/summary')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async paymentSummary(
    @CurrentUser() user: any,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { cash: 0, card: 0, total: 0, count: 0 };
    }
    const start = new Date(from);
    const end = new Date(to);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      return { cash: 0, card: 0, total: 0, count: 0 };
    }
    return this.ordersService.paymentSummary(organizationId, start, end);
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

  @Post(':id/payments')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async addPayment(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: PaymentBody,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' } as any;
    }
    return this.ordersService.addPayment(+id, organizationId, body, user);
  }

  @Post(':id/refunds')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async refund(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: PaymentBody,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' } as any;
    }
    return this.ordersService.refundPayment(
      +id,
      organizationId,
      body,
      user?.id ?? user?.userId ?? null,
    );
  }

  @Post(':id/returns')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async openReturn(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: never,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' } as any;
    }
    return this.saleReturnsService.open(
      +id,
      organizationId,
      user?.id ?? user?.userId ?? null,
      body,
    );
  }

  @Delete(':id/payments/:paymentId')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async removePayment(
    @Param('id') id: string,
    @Param('paymentId') paymentId: string,
    @CurrentUser() user: any,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { error: 'No active organization' } as any;
    }
    return this.ordersService.removePayment(+id, +paymentId, organizationId);
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

