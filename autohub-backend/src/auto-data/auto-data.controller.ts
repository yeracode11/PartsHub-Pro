import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AutoDataService } from './auto-data.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@Controller('api/auto-data')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AutoDataController {
  constructor(private readonly autoDataService: AutoDataService) {}

  @Get('brands')
  async getBrands() {
    return this.autoDataService.getBrands();
  }

  @Get('brands/:brandSlug/models')
  async getModels(@Param('brandSlug') brandSlug: string) {
    return this.autoDataService.getModels(brandSlug);
  }

  @Get('brands/:brandSlug/models/:modelSlug/generations')
  async getGenerations(
    @Param('brandSlug') brandSlug: string,
    @Param('modelSlug') modelSlug: string,
  ) {
    return this.autoDataService.getGenerations(brandSlug, modelSlug);
  }
}


