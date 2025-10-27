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

@Controller('api/orders')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get('recent')
  getRecentOrders(
    @Query('limit') limit: string = '5',
    @CurrentUser() user: any,
  ) {
    return this.ordersService.getRecentOrders(user.organizationId, parseInt(limit));
  }

  @Get()
  findAll(@CurrentUser() user: any) {
    return this.ordersService.findAll(user.organizationId);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.ordersService.findOne(+id, user.organizationId);
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  create(@CurrentUser() user: any, @Body() data: any) {
    return this.ordersService.create(user.organizationId, data);
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() data: any,
  ) {
    return this.ordersService.update(+id, user.organizationId, data);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  remove(@Param('id') id: string, @CurrentUser() user: any) {
    return this.ordersService.remove(+id, user.organizationId);
  }
}

