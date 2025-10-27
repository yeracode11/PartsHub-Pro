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
} from '@nestjs/common';
import { CustomersService } from './customers.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';

@Controller('api/customers')
//@UseGuards(JwtAuthGuard, RolesGuard)
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Get('top')
  getTopCustomers(
    @Query('limit') limit: string = '10',
    @CurrentUser() user: any,
  ) {
    return this.customersService.getTopCustomers(
      user.organizationId,
      parseInt(limit),
    );
  }

  @Get()
  findAll(@CurrentUser() user: any) {
    return this.customersService.findAll(user.organizationId);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.customersService.findOne(+id, user.organizationId);
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  create(@CurrentUser() user: any, @Body() data: any) {
    return this.customersService.create(user.organizationId, data);
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() data: any,
  ) {
    return this.customersService.update(+id, user.organizationId, data);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  remove(@Param('id') id: string, @CurrentUser() user: any) {
    return this.customersService.remove(+id, user.organizationId);
  }
}
