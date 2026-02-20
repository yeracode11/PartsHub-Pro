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
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { IncomingService } from './incoming.service';
import { CreateIncomingDocDto } from './dto/create-incoming-doc.dto';
import { CreateIncomingItemDto } from './dto/create-incoming-item.dto';
import { UpdateIncomingDocDto } from './dto/update-incoming-doc.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { IncomingDocStatus } from './entities/incoming-doc.entity';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('api/incoming')
@UseGuards(JwtAuthGuard, RolesGuard)
export class IncomingController {
  constructor(
    private readonly incomingService: IncomingService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  // Получение organizationId с fallback
  private async resolveOrganizationId(user: any): Promise<string | null> {
    try {
      if (user?.organizationId) {
        return user.organizationId;
      }
      // Fallback: находим первую активную организацию
      const orgs = await this.organizationsService.findAll();
      if (orgs.length > 0) {
        return orgs[0].id;
      }
      return null;
    } catch (error) {
      return null;
    }
  }

  // Создание приходной накладной
  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async create(
    @CurrentUser() user: any,
    @Body() dto: CreateIncomingDocDto,
  ) {
    try {
      // Проверяем разные варианты получения ID
      const userId = user?.id || user?.userId;
      
      if (!userId) {
        throw new HttpException(
          {
            statusCode: HttpStatus.BAD_REQUEST,
            message: 'User ID is missing. User object: ' + JSON.stringify(user),
            error: 'Bad Request',
          },
          HttpStatus.BAD_REQUEST,
        );
      }
      
      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        throw new Error('No active organization');
      }

      const result = await this.incomingService.create(organizationId, userId, dto);
      return result;
    } catch (error) {
      // Преобразуем ошибку в HttpException для правильной обработки
      if (error instanceof HttpException) {
        throw error;
      }
      if (error instanceof Error) {
        throw new HttpException(
          {
            statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
            message: `Ошибка создания накладной: ${error.message}`,
            error: 'Internal Server Error',
          },
          HttpStatus.INTERNAL_SERVER_ERROR,
        );
      }
      throw new HttpException(
        {
          statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
          message: 'Неизвестная ошибка при создании накладной',
          error: 'Internal Server Error',
        },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  // Получение списка накладных
  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async findAll(
    @CurrentUser() user: any,
    @Query('status') status?: string,
    @Query('dateFrom') dateFrom?: string,
    @Query('dateTo') dateTo?: string,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }

    const filters: any = {};
    if (status) {
      filters.status = status as IncomingDocStatus;
    }
    if (dateFrom) {
      filters.dateFrom = new Date(dateFrom);
    }
    if (dateTo) {
      filters.dateTo = new Date(dateTo);
    }

    return this.incomingService.findAll(organizationId, filters);
  }

  // Получение одной накладной
  @Get(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async findOne(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }
    return this.incomingService.findOne(id, organizationId);
  }

  // Обновление накладной
  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: UpdateIncomingDocDto,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }
    return this.incomingService.update(id, organizationId, dto);
  }

  // Добавление позиции в накладную
  @Post(':id/items')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async addItem(
    @Param('id') docId: string,
    @CurrentUser() user: any,
    @Body() dto: CreateIncomingItemDto,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }
    return this.incomingService.addItem(docId, organizationId, dto);
  }

  // Удаление позиции
  @Delete('items/:itemId')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async removeItem(@Param('itemId') itemId: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }
    await this.incomingService.removeItem(itemId, organizationId);
    return { success: true };
  }

  // Проведение накладной
  @Post(':id/process')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async processDocument(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }
    return this.incomingService.processDocument(id, organizationId);
  }

  // Удаление накладной
  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async remove(@Param('id') id: string, @CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      throw new Error('No active organization');
    }
    await this.incomingService.remove(id, organizationId);
    return { success: true };
  }
}

