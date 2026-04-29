import {
  Body,
  Controller,
  Get,
  Patch,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../common/enums/user-role.enum';

/**
 * Маршруты для macOS Admin (платформа): пока заглушки, чтобы клиент не получал 404.
 * Расширять при появлении сущностей подписок и транзакций в БД.
 */
@Controller('api')
export class PlatformAdminController {
  @Get('subscriptions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPERADMIN)
  listSubscriptions() {
    return [];
  }

  @Patch('subscriptions/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPERADMIN)
  patchSubscription(@Param('id') id: string, @Body() body: Record<string, unknown>) {
    return {
      id,
      userId: '',
      plan: body.plan ?? null,
      isActive: body.isActive !== undefined ? Boolean(body.isActive) : true,
      expiresAt: body.expiresAt ?? null,
      createdAt: new Date().toISOString(),
    };
  }

  @Get('transactions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPERADMIN)
  listTransactions(
    @Query('from') _from?: string,
    @Query('to') _to?: string,
    @Query('userId') _userId?: string,
  ) {
    return [];
  }
}
