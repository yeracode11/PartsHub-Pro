import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Patch,
  Body,
  Param,
  UseGuards,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';

function isSuperAdmin(user: any): boolean {
  return user?.role === UserRole.SUPERADMIN;
}

function requireOrganization(user: any): string {
  const organizationId = user?.organizationId;
  if (!organizationId) {
    throw new ForbiddenException('Нет организации');
  }
  return organizationId;
}

class UpdateStaffPayBody {
  payType?: string;
  payRate?: number;
}

@Controller('api/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPERADMIN)
  create(@Body() createDto: CreateUserDto) {
    return this.usersService.create(createDto);
  }

  @Post('sync') // Для синхронизации с Firebase
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPERADMIN)
  createOrUpdate(@Body() createDto: CreateUserDto) {
    return this.usersService.createOrUpdate(createDto);
  }

  @Get('firebase/:uid')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPERADMIN)
  findByFirebaseUid(@Param('uid') uid: string) {
    return this.usersService.findByFirebaseUid(uid);
  }

  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.OWNER, UserRole.SUPERADMIN)
  findAll(@CurrentUser() user: any) {
    if (isSuperAdmin(user)) {
      return this.usersService.findAll();
    }
    return this.usersService.findByOrganization(requireOrganization(user));
  }

  @Get('staff')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.OWNER)
  listMasters(@CurrentUser() user: any) {
    const organizationId = user?.organizationId;
    if (!organizationId) {
      throw new ForbiddenException('Нет организации');
    }
    return this.usersService.listMasters(organizationId);
  }

  @Post('staff')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.OWNER)
  createMaster(@CurrentUser() user: any, @Body() dto: CreateStaffDto) {
    const organizationId = user?.organizationId;
    if (!organizationId) {
      throw new ForbiddenException('Нет организации');
    }
    return this.usersService.createMaster(organizationId, dto);
  }

  @Patch('staff/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.OWNER)
  updateMasterPay(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: UpdateStaffPayBody,
  ) {
    const organizationId = user?.organizationId;
    if (!organizationId) {
      throw new ForbiddenException('Нет организации');
    }
    return this.usersService.updateMasterPay(
      organizationId,
      id,
      body?.payType,
      body?.payRate,
    );
  }

  @Delete('staff/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.OWNER)
  removeMaster(@CurrentUser() user: any, @Param('id') id: string) {
    const organizationId = user?.organizationId;
    if (!organizationId) {
      throw new ForbiddenException('Нет организации');
    }
    return this.usersService.removeMaster(organizationId, id);
  }

  @Get('organization/:organizationId')
  @UseGuards(JwtAuthGuard)
  findByOrganization(
    @CurrentUser() user: any,
    @Param('organizationId') organizationId: string,
  ) {
    if (!isSuperAdmin(user) && organizationId !== requireOrganization(user)) {
      throw new ForbiddenException('Нет доступа к этой организации');
    }
    return this.usersService.findByOrganization(organizationId);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async findOne(@CurrentUser() user: any, @Param('id') id: string) {
    const found = await this.usersService.findOne(id);
    if (!isSuperAdmin(user) && found.organizationId !== requireOrganization(user)) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }
    return found;
  }

  // Обновление профиля пользователя (только для владельца)
  @Put('profile')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(
    UserRole.OWNER,
    UserRole.SUPERADMIN,
    UserRole.WORKER,
    UserRole.MANAGER,
    UserRole.STOREKEEPER,
  )
  async updateProfile(
    @CurrentUser() user: any,
    @Body() updateDto: UpdateUserDto,
  ) {
    const updatedUser = await this.usersService.updateProfile(user.id, updateDto);
    
    // Загружаем с организацией для ответа
    return await this.usersService.findOne(updatedUser.id);
  }
}
