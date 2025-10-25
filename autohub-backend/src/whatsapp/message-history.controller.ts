import {
  Controller,
  Get,
  Query,
  Param,
  UseGuards,
} from '@nestjs/common';
import { MessageHistoryService } from './message-history.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('api/whatsapp/history')
@UseGuards(JwtAuthGuard, RolesGuard)
export class MessageHistoryController {
  constructor(
    private readonly messageHistoryService: MessageHistoryService,
  ) {}

  @Get()
  findAll(
    @CurrentUser() user: any,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.messageHistoryService.findAll(user.organizationId, {
      limit: limit ? parseInt(limit) : undefined,
      offset: offset ? parseInt(offset) : undefined,
    });
  }

  @Get('stats')
  getStats(
    @CurrentUser() user: any,
    @Query('period') period?: string,
  ) {
    return this.messageHistoryService.getStats(user.organizationId, period);
  }

  @Get('campaign/:name')
  findByCampaign(
    @Param('name') name: string,
    @CurrentUser() user: any,
  ) {
    return this.messageHistoryService.findByCampaign(
      user.organizationId,
      name,
    );
  }

  @Get('customer/:id')
  findByCustomer(
    @Param('id') id: string,
    @CurrentUser() user: any,
  ) {
    return this.messageHistoryService.findByCustomer(
      user.organizationId,
      parseInt(id),
    );
  }
}

