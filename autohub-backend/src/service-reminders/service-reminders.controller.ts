import { Body, Controller, Get, Post, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { ServiceRemindersService } from './service-reminders.service';

@Controller('api/service-reminders')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ServiceRemindersController {
  constructor(private readonly reminders: ServiceRemindersService) {}

  /** Настройки, ближайшие напоминания и журнал отправок. */
  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  getOverview(@CurrentUser() user: any) {
    return this.reminders.getOverview(user.organizationId);
  }

  /** Включение и параметры. Включение создаёт шаблон в WhatsApp Business. */
  @Put('settings')
  @Roles(UserRole.OWNER)
  updateSettings(
    @CurrentUser() user: any,
    @Body() body: { enabled?: boolean; daysBefore?: number; connectionId?: string | null },
  ) {
    return this.reminders.updateSettings(user.organizationId, {
      enabled: body?.enabled,
      daysBefore: body?.daysBefore,
      connectionId: body?.connectionId,
    });
  }

  /** Отправить то, что пора, не дожидаясь фоновой задачи. */
  @Post('run')
  @Roles(UserRole.OWNER)
  run(@CurrentUser() user: any) {
    return this.reminders.runForOrganization(user.organizationId);
  }
}
