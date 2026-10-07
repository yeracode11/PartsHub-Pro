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
import { WarehouseLocationsService } from './warehouse-locations.service';
import { WriteOffsService } from './write-offs.service';
import { StocktakingsService } from './stocktakings.service';
import { InventoryService } from './inventory.service';

const STOCK_ROLES = [UserRole.OWNER, UserRole.MANAGER, UserRole.STOREKEEPER];

@Controller('api/warehouse-locations')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WarehouseLocationsController {
  constructor(private readonly locations: WarehouseLocationsService) {}

  @Get()
  @Roles(...STOCK_ROLES)
  list(
    @CurrentUser() user: { organizationId: string },
    @Query('warehouseId') warehouseId?: string,
  ) {
    return this.locations.list(user.organizationId, warehouseId);
  }

  @Post()
  @Roles(...STOCK_ROLES)
  create(@CurrentUser() user: { organizationId: string }, @Body() body: never) {
    return this.locations.create(user.organizationId, body);
  }

  @Delete(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  remove(
    @CurrentUser() user: { organizationId: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.locations.remove(id, user.organizationId);
  }
}

@Controller('api/write-offs')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WriteOffsController {
  constructor(private readonly writeOffs: WriteOffsService) {}

  @Get()
  @Roles(...STOCK_ROLES)
  list(@CurrentUser() user: { organizationId: string }) {
    return this.writeOffs.list(user.organizationId);
  }

  @Post()
  @Roles(...STOCK_ROLES)
  create(
    @CurrentUser() user: { organizationId: string; id?: string },
    @Body() body: never,
  ) {
    return this.writeOffs.create(user.organizationId, user.id ?? null, body);
  }
}

@Controller('api/stocktakings')
@UseGuards(JwtAuthGuard, RolesGuard)
export class StocktakingsController {
  constructor(private readonly stocktakings: StocktakingsService) {}

  @Get()
  @Roles(...STOCK_ROLES)
  list(@CurrentUser() user: { organizationId: string }) {
    return this.stocktakings.list(user.organizationId);
  }

  @Post()
  @Roles(...STOCK_ROLES)
  create(
    @CurrentUser() user: { organizationId: string; id?: string },
    @Body() body: { warehouseId?: string },
  ) {
    return this.stocktakings.create(
      user.organizationId,
      user.id ?? null,
      body?.warehouseId ?? '',
    );
  }

  @Get(':id')
  @Roles(...STOCK_ROLES)
  findOne(
    @CurrentUser() user: { organizationId: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.stocktakings.findOne(id, user.organizationId);
  }

  @Post(':id/lines')
  @Roles(...STOCK_ROLES)
  count(
    @CurrentUser() user: { organizationId: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: never,
  ) {
    return this.stocktakings.count(id, user.organizationId, body);
  }

  @Post(':id/approve')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  approve(
    @CurrentUser() user: { organizationId: string; id?: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.stocktakings.approve(id, user.organizationId, user.id ?? null);
  }
}

@Controller('api/items')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ItemMovementsController {
  constructor(private readonly inventory: InventoryService) {}

  @Get(':id/movements')
  @Roles(...STOCK_ROLES)
  history(
    @CurrentUser() user: { organizationId: string },
    @Param('id') id: string,
  ) {
    return this.inventory.history(user.organizationId, Number(id));
  }
}
