import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { ListingsService } from './listings.service';

@Controller('api/listings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.OWNER, UserRole.MANAGER)
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get()
  list(
    @CurrentUser() user: { organizationId: string },
    @Query('itemId') itemId?: string,
  ) {
    const parsed = itemId ? Number(itemId) : undefined;
    return this.listings.list(
      user.organizationId,
      parsed && Number.isInteger(parsed) ? parsed : undefined,
    );
  }

  @Post()
  create(@CurrentUser() user: { organizationId: string }, @Body() body: never) {
    return this.listings.create(user.organizationId, body);
  }

  @Post(':id/publish')
  publish(
    @CurrentUser() user: { organizationId: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listings.publish(id, user.organizationId);
  }

  @Post(':id/pause')
  pause(
    @CurrentUser() user: { organizationId: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listings.pause(id, user.organizationId);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: { organizationId: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listings.remove(id, user.organizationId);
  }
}
