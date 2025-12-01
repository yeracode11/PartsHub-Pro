import { Controller, Get, Param, UseGuards, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { AutoDataService, KolesaGeneration, KolesaListItem } from './auto-data.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@Controller('api/auto-data')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AutoDataController {
  private readonly logger = new Logger(AutoDataController.name);

  constructor(private readonly autoDataService: AutoDataService) {}

  @Get('brands')
  async getBrands(): Promise<KolesaListItem[]> {
    try {
      const brands = await this.autoDataService.getBrands();
      this.logger.log(`✅ Successfully fetched ${brands?.length || 0} brands from Kolesa.kz`);
      return brands || [];
    } catch (error: any) {
      this.logger.warn(`⚠️ Error fetching brands from Kolesa.kz: ${error.message}. Using static list.`);
      // Возвращаем статический список популярных марок
      const staticBrands = this.autoDataService.getStaticBrands();
      this.logger.log(`✅ Returning ${staticBrands.length} static brands`);
      return staticBrands;
    }
  }

  @Get('brands/:brandSlug/models')
  async getModels(@Param('brandSlug') brandSlug: string): Promise<KolesaListItem[]> {
    try {
      const models = await this.autoDataService.getModels(brandSlug);
      this.logger.log(`✅ Successfully fetched ${models?.length || 0} models for brand: ${brandSlug} from Kolesa.kz`);
      return models || [];
    } catch (error: any) {
      this.logger.warn(`⚠️ Error fetching models for ${brandSlug}: ${error.message}. Using static list.`);
      // Возвращаем статический список моделей для марки
      const staticModels = this.autoDataService.getStaticModels(brandSlug);
      this.logger.log(`✅ Returning ${staticModels.length} static models for ${brandSlug}`);
      return staticModels;
    }
  }

  @Get('brands/:brandSlug/models/:modelSlug/generations')
  async getGenerations(
    @Param('brandSlug') brandSlug: string,
    @Param('modelSlug') modelSlug: string,
  ): Promise<KolesaGeneration[]> {
    try {
      const generations = await this.autoDataService.getGenerations(brandSlug, modelSlug);
      this.logger.log(`✅ Successfully fetched ${generations?.length || 0} generations for ${brandSlug}/${modelSlug}`);
      return generations || [];
    } catch (error: any) {
      this.logger.warn(`⚠️ Error fetching generations for ${brandSlug}/${modelSlug}: ${error.message}. Returning empty array.`);
      // Поколения не критичны, возвращаем пустой массив
      return [];
    }
  }
}


