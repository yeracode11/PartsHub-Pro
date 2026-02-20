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
  UseInterceptors,
  UploadedFiles,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ItemsService } from './items.service';
import { FilterItemsDto } from './dto/filter-items.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { FileUploadService } from '../common/services/file-upload.service';

@Controller('api/items')
@UseGuards(JwtAuthGuard, RolesGuard) // Все методы требуют авторизации
export class ItemsController {
  private readonly logger = new Logger(ItemsController.name);

  constructor(private readonly itemsService: ItemsService) {}

  @Get('popular')
  getPopularItems(
    @Query('limit') limit: string = '5',
    @CurrentUser() user: any,
  ) {
    // Автоматически используем organizationId из JWT
    return this.itemsService.getPopularItems(user.organizationId, parseInt(limit));
  }

  @Get()
  async findAll(@CurrentUser() user: any, @Query() filters: FilterItemsDto) {
    try {
      if (!user || !user.organizationId) {
        this.logger.error('No organizationId in user');
        return [];
      }
      return await this.itemsService.findAll(user.organizationId, filters);
    } catch (error) {
      this.logger.error('Error in findAll controller', error.stack);
      // Возвращаем пустой массив только если это не критическая ошибка
      // Но логируем детали для отладки
      return [];
    }
  }

  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.itemsService.findOne(+id, user.organizationId);
  }

  @Post(':id/sync-to-b2c')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  syncToB2C(@Param('id') id: string, @CurrentUser() user: any) {
    return this.itemsService.syncToB2C(+id, user.organizationId);
  }

  @Post('sync-all-to-b2c')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  syncAllToB2C(@CurrentUser() user: any) {
    return this.itemsService.syncAllToB2C(user.organizationId);
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER) // Только эти роли могут создавать
  create(@CurrentUser() user: any, @Body() data: any) {
    return this.itemsService.create(user.organizationId, data);
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() data: any,
  ) {
    return this.itemsService.update(+id, user.organizationId, data);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER) // Только Owner и Manager могут удалять
  remove(@Param('id') id: string, @CurrentUser() user: any) {
    return this.itemsService.remove(+id, user.organizationId);
  }

  // Загрузка изображений для товара
  @Post(':id/images')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  @UseInterceptors(FilesInterceptor('images', 10, FileUploadService.getMulterConfig()))
  async uploadImages(
    @Param('id') id: string,
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: any,
  ) {
    if (!files || files.length === 0) {
      throw new BadRequestException('No files uploaded');
    }

    // Генерируем URLs для загруженных файлов
    const imageUrls = files.map(file => FileUploadService.generateFileUrl(file.filename));

    // Обновляем товар с новыми изображениями
    const result = await this.itemsService.addImages(+id, user.organizationId, imageUrls);

    return result;
  }

  // Тестовый endpoint для проверки
  @Post('test')
  async testEndpoint() {
    return { message: 'Test endpoint works' };
  }

  // Удаление изображения
  @Delete(':id/images')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async removeImage(
    @Param('id') id: string,
    @Body() body: { imageUrl: string },
    @CurrentUser() user: any,
  ) {
    return this.itemsService.removeImage(+id, user.organizationId, body.imageUrl);
  }
}

