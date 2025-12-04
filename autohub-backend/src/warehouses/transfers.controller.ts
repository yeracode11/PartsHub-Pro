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
import { TransfersService } from './transfers.service';
import { CreateTransferDto } from './dto/create-transfer.dto';
import { UpdateTransferStatusDto } from './dto/update-transfer-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('api/warehouse-transfers')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TransfersController {
  private readonly logger = new Logger(TransfersController.name);

  constructor(private readonly transfersService: TransfersService) {}

  @Post()
  async create(@Body() createTransferDto: CreateTransferDto, @CurrentUser() user: any) {
    try {
      this.logger.log(`Creating transfer for organization: ${user.organizationId}`);
      return await this.transfersService.create(createTransferDto, user.organizationId, user.userId);
    } catch (error) {
      this.logger.error(`Failed to create transfer: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to create transfer',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get()
  async findAll(@CurrentUser() user: any) {
    try {
      this.logger.log(`Fetching transfers for organization: ${user.organizationId}`);
      return await this.transfersService.findAll(user.organizationId);
    } catch (error) {
      this.logger.error(`Failed to fetch transfers: ${error.message}`, error.stack);
      throw new HttpException(
        'Failed to fetch transfers',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    try {
      this.logger.log(`Fetching transfer ${id} for organization: ${user.organizationId}`);
      return await this.transfersService.findOne(id, user.organizationId);
    } catch (error) {
      this.logger.error(`Failed to fetch transfer: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to fetch transfer',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() updateStatusDto: UpdateTransferStatusDto,
    @CurrentUser() user: any,
  ) {
    try {
      this.logger.log(`Updating transfer ${id} status for organization: ${user.organizationId}`);
      return await this.transfersService.updateStatus(
        id,
        updateStatusDto,
        user.organizationId,
        user.userId,
      );
    } catch (error) {
      this.logger.error(`Failed to update transfer status: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to update transfer status',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Delete(':id')
  async remove(@Param('id') id: string, @CurrentUser() user: any) {
    try {
      this.logger.log(`Deleting transfer ${id} for organization: ${user.organizationId}`);
      await this.transfersService.remove(id, user.organizationId);
      return { message: 'Transfer deleted successfully' };
    } catch (error) {
      this.logger.error(`Failed to delete transfer: ${error.message}`, error.stack);
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Failed to delete transfer',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

