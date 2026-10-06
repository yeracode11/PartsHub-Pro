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
  ParseIntPipe,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ItemsService } from './items.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { FileUploadService } from '../common/services/file-upload.service';
import { canSeeFinance } from '../common/finance-access';

const writeOptions = (user: any) => ({
  includeFinance: canSeeFinance(user),
  actorId: user?.id ?? null,
});

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
    return this.itemsService.getPopularItems(
      user.organizationId,
      parseInt(limit),
    );
  }

  /**
   * search — название, артикул, бренд, OEM и аналоги; code — точный штрихкод, артикул,
   * внутренний код или OEM (для сканера); limit/offset — постраничный ответ.
   */
  @Get()
  findAll(@CurrentUser() user: any, @Query() query: Record<string, unknown>) {
    if (!user?.organizationId) return [];
    return this.itemsService.findAll(user.organizationId, query, {
      includeFinance: canSeeFinance(user),
    });
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.itemsService.findOne(id, user.organizationId, {
      includeFinance: canSeeFinance(user),
    });
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
  create(@CurrentUser() user: any, @Body() data: unknown) {
    return this.itemsService.create(
      user.organizationId,
      data,
      writeOptions(user),
    );
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() data: unknown,
  ) {
    return this.itemsService.update(
      id,
      user.organizationId,
      data,
      writeOptions(user),
    );
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER) // Только Owner и Manager могут удалять
  remove(@Param('id') id: string, @CurrentUser() user: any) {
    return this.itemsService.remove(+id, user.organizationId);
  }

  // Загрузка изображений для товара
  @Post(':id/images')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  @UseInterceptors(
    FilesInterceptor('images', 10, FileUploadService.getMulterConfig()),
  )
  async uploadImages(
    @Param('id') id: string,
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: any,
  ) {
    if (!files || files.length === 0) {
      throw new BadRequestException('No files uploaded');
    }

    // Генерируем URLs для загруженных файлов
    const imageUrls = files.map((file) =>
      FileUploadService.generateFileUrl(file.filename),
    );

    // Обновляем товар с новыми изображениями
    const result = await this.itemsService.addImages(
      +id,
      user.organizationId,
      imageUrls,
    );

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
    return this.itemsService.removeImage(
      +id,
      user.organizationId,
      body.imageUrl,
    );
  }
}
