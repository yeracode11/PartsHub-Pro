import { Controller, Get, Query, UseGuards, Logger } from '@nestjs/common';
import { DashboardService } from './dashboard.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('api/dashboard')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DashboardController {
  private readonly logger = new Logger(DashboardController.name);

  constructor(
    private readonly dashboardService: DashboardService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  private async resolveOrganizationId(user: any): Promise<string | null> {
    if (user && user.organizationId) {
      return user.organizationId;
    }
    const orgs = await this.organizationsService.findAll();
    return orgs?.[0]?.id ?? null;
  }

  @Get('stats')
  async getStats(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { totalRevenue: 0, monthlyRevenue: 0, inventoryCount: 0, activeOrdersCount: 0, period: new Date().toISOString().substring(0, 7) };
    }
    return this.dashboardService.getStats(organizationId);
  }

  @Get('sales-chart')
  async getSalesChart(
    @Query('period') period: string = '7d',
    @CurrentUser() user: any,
  ) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { points: [] } as any;
    }
    return this.dashboardService.getSalesChart(organizationId, period);
  }

  @Get('category-stats')
  async getCategoryStats(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return { categories: [] } as any;
    }
    return this.dashboardService.getCategoryStats(organizationId);
  }

  @Get('advanced')
  async getAdvancedAnalytics(@CurrentUser() user: any) {
    const organizationId = await this.resolveOrganizationId(user);
    if (!organizationId) {
      return {} as any;
    }
    return this.dashboardService.getAdvancedAnalytics(organizationId);
  }

  @Get('top-selling-items')
  async getTopSellingItems(
    @Query('limit') limit: string = '10',
    @CurrentUser() user: any,
  ) {
    try {
      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        return { items: [] } as any;
      }
      return await this.dashboardService.getTopSellingItems(organizationId, parseInt(limit) || 10);
    } catch (error) {
      this.logger.error('Error in getTopSellingItems controller', error.stack);
      return { items: [] } as any;
    }
  }

  @Get('low-stock-items')
  async getLowStockItems(
    @Query('threshold') threshold: string = '5',
    @CurrentUser() user: any,
  ) {
    try {
      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        return { items: [] } as any;
      }
      return await this.dashboardService.getLowStockItems(organizationId, parseInt(threshold) || 5);
    } catch (error) {
      this.logger.error('Error in getLowStockItems controller', error.stack);
      return { items: [] } as any;
    }
  }

  @Get('sales-by-category')
  async getSalesByCategory(@CurrentUser() user: any) {
    try {
      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        return { categories: [] } as any;
      }
      return await this.dashboardService.getSalesByCategory(organizationId);
    } catch (error) {
      this.logger.error('Error in getSalesByCategory controller', error.stack);
      return { categories: [] } as any;
    }
  }

  @Get('abc-xyz')
  async getAbcXyz(@CurrentUser() user: any) {
    try {
      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        return { summary: {}, items: [] } as any;
      }
      return await this.dashboardService.getAbcXyz(organizationId);
    } catch (error) {
      this.logger.error('Error in getAbcXyz controller', error.stack);
      return { summary: {}, items: [] } as any;
    }
  }

  @Get('staff-report')
  async getStaffReport(
    @Query('period') period: string = '30d',
    @CurrentUser() user: any,
  ) {
    try {
      const organizationId = await this.resolveOrganizationId(user);
      if (!organizationId) {
        return { items: [] } as any;
      }
      return await this.dashboardService.getStaffReport(organizationId, period);
    } catch (error) {
      this.logger.error('Error in getStaffReport controller', error.stack);
      return { items: [] } as any;
    }
  }
}

