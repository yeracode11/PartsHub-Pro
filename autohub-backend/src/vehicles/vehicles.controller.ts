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
import { VehiclesService } from './vehicles.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';

@Controller('api/vehicles')
@UseGuards(JwtAuthGuard, RolesGuard)
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  /**
   * GET /api/vehicles - получить все автомобили
   */
  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER, UserRole.WORKER)
  async findAll(@CurrentUser() user: any) {
    return await this.vehiclesService.findAll(user.organizationId);
  }

  /**
   * GET /api/vehicles/customer/:customerId - автомобили клиента
   */
  @Get('customer/:customerId')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async findByCustomer(
    @CurrentUser() user: any,
    @Param('customerId') customerId: string,
  ) {
    return await this.vehiclesService.findByCustomer(
      user.organizationId,
      parseInt(customerId, 10),
    );
  }

  /**
   * GET /api/vehicles/upcoming-service - автомобили с близким ТО
   */
  @Get('upcoming-service')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER, UserRole.WORKER)
  async getUpcomingService(@CurrentUser() user: any) {
    return await this.vehiclesService.getUpcomingService(user.organizationId);
  }

  /**
   * GET /api/vehicles/search?q=... - поиск по номеру/VIN
   */
  @Get('search')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async search(
    @CurrentUser() user: any,
    @Query('q') query: string,
  ) {
    return await this.vehiclesService.search(user.organizationId, query);
  }

  /**
   * GET /api/vehicles/:id - получить один автомобиль
   */
  @Get(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async findOne(@CurrentUser() user: any, @Param('id') id: string) {
    return await this.vehiclesService.findOne(
      parseInt(id, 10),
      user.organizationId,
    );
  }

  /**
   * POST /api/vehicles - создать автомобиль
   */
  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async create(@CurrentUser() user: any, @Body() data: any) {
    return await this.vehiclesService.create(user.organizationId, data);
  }

  /**
   * PUT /api/vehicles/:id - обновить автомобиль
   */
  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async update(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() data: any,
  ) {
    return await this.vehiclesService.update(
      parseInt(id, 10),
      user.organizationId,
      data,
    );
  }

  /**
   * DELETE /api/vehicles/:id - удалить автомобиль
   */
  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async remove(@CurrentUser() user: any, @Param('id') id: string) {
    return await this.vehiclesService.remove(
      parseInt(id, 10),
      user.organizationId,
    );
  }

  /**
   * PUT /api/vehicles/:id/mileage - обновить пробег
   */
  @Put(':id/mileage')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async updateMileage(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body('mileage') mileage: number,
  ) {
    return await this.vehiclesService.updateMileage(
      parseInt(id, 10),
      user.organizationId,
      mileage,
    );
  }

  /**
   * POST /api/vehicles/:id/service - записать ТО
   */
  @Post(':id/service')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async recordService(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() data: any,
  ) {
    return await this.vehiclesService.recordService(
      parseInt(id, 10),
      user.organizationId,
      data,
    );
  }
}

