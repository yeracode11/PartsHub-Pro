import { Controller, Get, NotFoundException, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { VehicleReferenceService } from '../vehicle-reference/vehicle-reference.service';

/** Старый путь приложения. Данные берутся из локального справочника, не из Kolesa. */
@Controller('api/auto-data')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AutoDataController {
  constructor(private readonly catalog: VehicleReferenceService) {}

  @Get('brands')
  async getBrands() {
    const items = await this.catalog.listMakes();
    return items.map((item) => ({ name: item.name, slug: item.slug }));
  }

  @Get('brands/:brandSlug/models')
  async getModels(@Param('brandSlug') brandSlug: string) {
    const make = await this.catalog.findMakeBySlug(brandSlug);
    if (!make) throw new NotFoundException('Марка не найдена');
    const items = await this.catalog.listModels(make.id);
    return items.map((item) => ({ name: item.name, slug: item.slug }));
  }

  @Get('brands/:brandSlug/models/:modelSlug/generations')
  async getGenerations(
    @Param('brandSlug') brandSlug: string,
    @Param('modelSlug') modelSlug: string,
  ) {
    const make = await this.catalog.findMakeBySlug(brandSlug);
    if (!make) return [];
    const model = await this.catalog.findModelBySlug(make.id, modelSlug);
    if (!model) return [];
    const items = await this.catalog.listGenerations(model.id);
    return items.map((item) => ({
      name: item.name,
      slug: item.slug,
      year_from: item.yearFrom,
      year_to: item.yearTo,
    }));
  }
}
