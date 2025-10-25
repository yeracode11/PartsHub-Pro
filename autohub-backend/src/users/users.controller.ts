import { Controller, Get, Post, Body, Param, Query } from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';

@Controller('api/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  create(@Body() createDto: CreateUserDto) {
    return this.usersService.create(createDto);
  }

  @Post('sync') // Для синхронизации с Firebase
  createOrUpdate(@Body() createDto: CreateUserDto) {
    return this.usersService.createOrUpdate(createDto);
  }

  @Get('firebase/:uid')
  findByFirebaseUid(@Param('uid') uid: string) {
    return this.usersService.findByFirebaseUid(uid);
  }

  @Get('organization/:organizationId')
  findByOrganization(@Param('organizationId') organizationId: string) {
    return this.usersService.findByOrganization(organizationId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }
}
