import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { VehicleReferenceService } from './vehicle-reference.service';

/**
 * Глобальный справочник. Не путать с /api/vehicles/search — это поиск машин клиентов.
 */
@Controller('api/vehicles')
@UseGuards(JwtAuthGuard, RolesGuard)
export class VehicleReferenceController {
  constructor(private readonly catalog: VehicleReferenceService) {}

  @Get('makes')
  async makes(@Query('search') search?: string) {
    return { items: await this.catalog.listMakes(search) };
  }

  @Get('makes/:makeId/models')
  async models(
    @Param('makeId', ParseIntPipe) makeId: number,
    @Query('search') search?: string,
  ) {
    return { items: await this.catalog.listModels(makeId, search) };
  }

  @Get('models/:modelId/generations')
  async generations(
    @Param('modelId', ParseIntPipe) modelId: number,
    @Query('search') search?: string,
  ) {
    return { items: await this.catalog.listGenerations(modelId, search) };
  }

  @Get('tree')
  tree(@Query('makeId') makeId?: string, @Query('modelId') modelId?: string) {
    return this.catalog.treeSlice(this.optionalId(makeId), this.optionalId(modelId));
  }

  @Get('lookup')
  async lookup(@Query('q') q = '') {
    return { items: await this.catalog.search(q) };
  }

  private optionalId(value?: string) {
    if (!value) return undefined;
    const id = Number(value);
    return Number.isInteger(id) && id > 0 ? id : undefined;
  }
}
