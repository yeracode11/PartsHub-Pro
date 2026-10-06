import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PayrollService } from './payroll.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';

class SetWorkDoneBody {
  done: boolean;
}

@Controller('api/payroll')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WORKER)
export class PayrollController {
  constructor(private readonly payrollService: PayrollService) {}

  @Get()
  report(
    @CurrentUser() user: any,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    const organizationId = user?.organizationId;
    if (!organizationId) {
      throw new ForbiddenException('Нет организации');
    }
    const start = new Date(from);
    const end = new Date(to);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      return { from: null, to: null, masters: [] };
    }
    return this.payrollService.report(organizationId, start, end, user);
  }

  @Patch('works/:id')
  setDone(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: SetWorkDoneBody,
  ) {
    const organizationId = user?.organizationId;
    if (!organizationId) {
      throw new ForbiddenException('Нет организации');
    }
    return this.payrollService.setWorkDone(
      organizationId,
      +id,
      Boolean(body?.done),
      user,
    );
  }
}
