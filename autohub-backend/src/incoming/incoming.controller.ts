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
        console.log('   Using user.organizationId:', user.organizationId);
        return user.organizationId;
      }
      // Fallback: находим первую активную организацию
      console.log('   User organizationId not found, searching for active organizations...');
      const orgs = await this.organizationsService.findAll();
      console.log('   Found organizations:', orgs.length);
      if (orgs.length > 0) {
        console.log('   Using first organization:', orgs[0].id);
        return orgs[0].id;
      }
      console.log('   No organizations found');
      return null;
    } catch (error) {
      console.error('   Error resolving organizationId:', error);
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
      console.log('📝 IncomingController.create - Request received');
      console.log('   Full user object:', JSON.stringify(user, null, 2));
      console.log('   User keys:', user ? Object.keys(user) : 'user is null/undefined');
      console.log('   User.id:', user?.id);
      console.log('   User.userId:', user?.userId);
      console.log('   User type:', typeof user);
      console.log('   DTO:', JSON.stringify(dto, null, 2));

      // Проверяем разные варианты получения ID
      const userId = user?.id || user?.userId;
      
      if (!userId) {
        console.error('   ❌ ERROR: No user ID found in user object');
        console.error('   User object:', user);
        throw new HttpException(
          {
            statusCode: HttpStatus.BAD_REQUEST,
            message: 'User ID is missing. User object: ' + JSON.stringify(user),
            error: 'Bad Request',
          },
          HttpStatus.BAD_REQUEST,
        );
      }
      
      console.log('   Using userId:', userId);

      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        throw new Error('No active organization');
      }

      console.log('   OrganizationId:', organizationId);
      console.log('   User ID to pass:', userId);
      console.log('   User ID type:', typeof userId);
      console.log('   User ID value:', JSON.stringify(userId));
      
      const result = await this.incomingService.create(organizationId, userId, dto);
      console.log('✅ IncomingController.create - Success:', result.id);
      
      return result;
    } catch (error) {
      console.error('❌ IncomingController.create - Error:', error);
      console.error('   Error name:', error?.constructor?.name);
      console.error('   Error message:', error?.message);
      console.error('   Error stack:', error?.stack);
      
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

