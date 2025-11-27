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
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ItemsService } from './items.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { FileUploadService } from '../common/services/file-upload.service';

@Controller('api/items')
@UseGuards(JwtAuthGuard, RolesGuard) // Все методы требуют авторизации
export class ItemsController {
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
  async findAll(@CurrentUser() user: any) {
    try {
      if (!user || !user.organizationId) {
        console.error('❌ No organizationId in user:', user);
        return [];
      }
      return await this.itemsService.findAll(user.organizationId);
    } catch (error) {
      console.error('❌ Error in findAll controller:', error);
      console.error('Error stack:', error?.stack);
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
    console.log('📸 Upload images called:', { itemId: id, filesCount: files?.length });
    
    if (!files || files.length === 0) {
      console.error('❌ No files uploaded');
      throw new BadRequestException('No files uploaded');
    }

    console.log('📸 Files received:', files.map(f => ({ 
      filename: f.filename, 
      mimetype: f.mimetype, 
      size: f.size 
    })));

    // Генерируем URLs для загруженных файлов
    const imageUrls = files.map(file => FileUploadService.generateFileUrl(file.filename));
    
    console.log('📸 Generated URLs:', imageUrls);
    
    // Обновляем товар с новыми изображениями
    const result = await this.itemsService.addImages(+id, user.organizationId, imageUrls);
    
    console.log('✅ Images added successfully:', result);
    
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
    console.log('🗑️ Removing image:', body.imageUrl);
    return this.itemsService.removeImage(+id, user.organizationId, body.imageUrl);
  }
}

