import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { WarehousesService } from './warehouses.service';
import { CreateWarehouseDto } from './dto/create-warehouse.dto';
import { UpdateWarehouseDto } from './dto/update-warehouse.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('api/warehouses')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WarehousesController {
  private readonly logger = new Logger(WarehousesController.name);

  constructor(private readonly warehousesService: WarehousesService) {}

  @Post()
  async create(@Body() createWarehouseDto: CreateWarehouseDto, @CurrentUser() user: any) {
    try {
      this.logger.log(`Creating warehouse for organization: ${user.organizationId}`);
      return await this.warehousesService.create(createWarehouseDto, user.organizationId);
    } catch (error) {
      this.logger.error(`Failed to create warehouse: ${error.message}`, error.stack);
      throw new HttpException(
        'Failed to create warehouse',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get()
  async findAll(@CurrentUser() user: any) {
    try {
      this.logger.log(`Fetching warehouses for organization: ${user.organizationId}`);
      return await this.warehousesService.findAll(user.organizationId);
    } catch (error) {
      this.logger.error(`Failed to fetch warehouses: ${error.message}`, error.stack);
      throw new HttpException(
        'Failed to fetch warehouses',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    try {
      this.logger.log(`Fetching warehouse ${id} for organization: ${user.organizationId}`);
      return await this.warehousesService.findOne(id, user.organizationId);
    } catch (error) {
      this.logger.error(`Failed to fetch warehouse: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to fetch warehouse',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':id/items-count')
  async getItemsCount(@Param('id') id: string, @CurrentUser() user: any) {
    try {
      this.logger.log(`Fetching items count for warehouse ${id}`);
      const count = await this.warehousesService.getItemsCount(id, user.organizationId);
      return { count };
    } catch (error) {
      this.logger.error(`Failed to fetch items count: ${error.message}`, error.stack);
      throw new HttpException(
        'Failed to fetch items count',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() updateWarehouseDto: UpdateWarehouseDto,
    @CurrentUser() user: any,
  ) {
    try {
      this.logger.log(`Updating warehouse ${id} for organization: ${user.organizationId}`);
      return await this.warehousesService.update(id, updateWarehouseDto, user.organizationId);
    } catch (error) {
      this.logger.error(`Failed to update warehouse: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to update warehouse',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Delete(':id')
  async remove(@Param('id') id: string, @CurrentUser() user: any) {
    try {
      this.logger.log(`Deleting warehouse ${id} for organization: ${user.organizationId}`);
      await this.warehousesService.remove(id, user.organizationId);
      return { message: 'Warehouse deleted successfully' };
    } catch (error) {
      this.logger.error(`Failed to delete warehouse: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to delete warehouse',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

