import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { DashboardService } from './dashboard.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('api/dashboard')
//@UseGuards(JwtAuthGuard)
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('stats')
  getStats(@CurrentUser() user: any) {
    return this.dashboardService.getStats(user.organizationId);
  }

  @Get('sales-chart')
  getSalesChart(
    @Query('period') period: string = '7d',
    @CurrentUser() user: any,
  ) {
    return this.dashboardService.getSalesChart(user.organizationId, period);
  }

  @Get('category-stats')
  getCategoryStats(@CurrentUser() user: any) {
    return this.dashboardService.getCategoryStats(user.organizationId);
  }
}

