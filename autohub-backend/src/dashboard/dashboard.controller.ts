import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { DashboardService } from './dashboard.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('api/dashboard')
@UseGuards(JwtAuthGuard)
export class DashboardController {
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
}

