import {
  Body,
  Controller,
  Get,
  Post,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { WhatsAppConnectionService } from './whatsapp-connection.service';

@Controller('api/whatsapp/connections')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WhatsAppConnectionController {
  constructor(
    private readonly connectionService: WhatsAppConnectionService,
  ) {}

  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  list(@CurrentUser() user: { organizationId: string }) {
    return this.connectionService.findAllByOrganization(user.organizationId);
  }

  @Post()
  @Roles(UserRole.OWNER)
  create(
    @CurrentUser() user: { organizationId: string },
    @Body()
    body: {
      phoneNumberId: string;
      accessToken: string;
      wabaId?: string;
      phoneNumber?: string;
      displayName?: string;
    },
  ) {
    if (!body.phoneNumberId?.trim() || !body.accessToken?.trim()) {
      throw new HttpException(
        'phoneNumberId and accessToken are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    return this.connectionService.createForOrganization(user.organizationId, {
      phoneNumberId: body.phoneNumberId.trim(),
      accessToken: body.accessToken.trim(),
      wabaId: body.wabaId?.trim(),
      phoneNumber: body.phoneNumber?.trim(),
      displayName: body.displayName?.trim(),
    });
  }
}
