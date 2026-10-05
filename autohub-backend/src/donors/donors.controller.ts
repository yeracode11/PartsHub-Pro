import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { unlink } from 'fs/promises';
import { basename, join } from 'path';
import { DonorsService } from './donors.service';
import {
  AddDonorPartsDto,
  CreateDonorDto,
  RemoveDonorPhotoDto,
  UpdateDonorDto,
} from './dto/donor.dto';
import { FileUploadService } from '../common/services/file-upload.service';
import { DonorStatus } from './entities/donor-vehicle.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';

/** Закупочные цены и прибыль видят только владелец и менеджер. */
const FINANCE_ROLES: string[] = [UserRole.OWNER, UserRole.MANAGER, UserRole.SUPERADMIN];
const canSeeFinance = (user: any) => FINANCE_ROLES.includes(user?.role);

/** basename не даёт выйти за пределы каталога загрузок через ../ в URL. */
const removeUploadedFile = (fileNameOrUrl: string) =>
  unlink(join(process.cwd(), 'uploads', 'items', basename(fileNameOrUrl))).catch(
    () => undefined,
  );

@Controller('api/donors')
@UseGuards(JwtAuthGuard, RolesGuard)
@UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
export class DonorsController {
  constructor(private readonly donorsService: DonorsService) {}

  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  findAll(@CurrentUser() user: any, @Query('status') status?: string) {
    if (status && !Object.values(DonorStatus).includes(status as DonorStatus)) {
      throw new BadRequestException('Неизвестный статус донора');
    }
    return this.donorsService.findAll(user.organizationId, {
      status: status as DonorStatus | undefined,
      includeFinance: canSeeFinance(user),
    });
  }

  @Get(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  findOne(@CurrentUser() user: any, @Param('id', ParseIntPipe) id: number) {
    return this.donorsService.findOne(id, user.organizationId, canSeeFinance(user));
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  create(@CurrentUser() user: any, @Body() dto: CreateDonorDto) {
    return this.donorsService.create(user.organizationId, dto);
  }

  @Put(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  update(
    @CurrentUser() user: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateDonorDto,
  ) {
    return this.donorsService.update(id, user.organizationId, dto);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  remove(@CurrentUser() user: any, @Param('id', ParseIntPipe) id: number) {
    return this.donorsService.remove(id, user.organizationId);
  }

  @Post(':id/photos')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  @UseInterceptors(
    FilesInterceptor('images', 10, FileUploadService.getMulterConfig()),
  )
  async addPhotos(
    @CurrentUser() user: any,
    @Param('id', ParseIntPipe) id: number,
    @UploadedFiles() files: Express.Multer.File[],
  ) {
    if (!files?.length) {
      throw new BadRequestException('Файлы не загружены');
    }
    try {
      return await this.donorsService.addPhotos(
        id,
        user.organizationId,
        files.map((f) => FileUploadService.generateFileUrl(f.filename)),
        canSeeFinance(user),
      );
    } catch (error) {
      await Promise.all(files.map((f) => removeUploadedFile(f.filename)));
      throw error;
    }
  }

  @Delete(':id/photos')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  async removePhoto(
    @CurrentUser() user: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RemoveDonorPhotoDto,
  ) {
    const result = await this.donorsService.removePhoto(
      id,
      user.organizationId,
      dto.imageUrl,
      canSeeFinance(user),
    );
    await removeUploadedFile(dto.imageUrl);
    return result;
  }

  /** Разборка: снятые детали сразу становятся товарами склада. */
  @Post(':id/parts')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER)
  addParts(
    @CurrentUser() user: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AddDonorPartsDto,
  ) {
    return this.donorsService.addParts(id, user.organizationId, dto);
  }
}
