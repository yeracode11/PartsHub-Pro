import {
  Body,
  Controller,
  Get,
  Post,
  UseGuards,
  UsePipes,
  ValidationPipe,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserRole } from '../common/enums/user-role.enum';
import { WhatsAppConnectionService } from './whatsapp-connection.service';
import { CreateWhatsAppConnectionDto } from './dto/create-whatsapp-connection.dto';

@Controller('api/whatsapp/connections')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WhatsAppConnectionController {
  constructor(
    private readonly connectionService: WhatsAppConnectionService,
  ) {}

  /** organizationId — только из JWT текущего пользователя, никогда из query/body. */
  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  list(@CurrentUser() user: { organizationId: string }) {
    return this.connectionService.findAllByOrganization(user.organizationId);
  }

  /**
   * Flutter body: { phoneNumberId, wabaId, displayName } — без accessToken.
   * organizationId — из JWT (@CurrentUser()), НИКОГДА из body.
   * accessToken — необязателен; если не передан, backend использует
   * META_WHATSAPP_ACCESS_TOKEN (см. WhatsAppConnectionService).
   * `whitelist: true` отбрасывает любые лишние поля (в т.ч. попытку
   * передать organizationId в теле запроса).
   */
  @Post()
  @Roles(UserRole.OWNER)
  @UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
  create(
    @CurrentUser() user: { organizationId: string },
    @Body() body: CreateWhatsAppConnectionDto,
  ) {
    if (!body.phoneNumberId?.trim()) {
      throw new HttpException(
        'phoneNumberId is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    return this.connectionService.createForOrganization(user.organizationId, {
      phoneNumberId: body.phoneNumberId.trim(),
      accessToken: body.accessToken?.trim(),
      wabaId: body.wabaId?.trim(),
      phoneNumber: body.phoneNumber?.trim(),
      displayName: body.displayName?.trim(),
    });
  }
}
