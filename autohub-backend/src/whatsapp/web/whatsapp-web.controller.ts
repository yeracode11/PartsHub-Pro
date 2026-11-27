import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { WhatsAppWebService } from './whatsapp-web.service';
import {
  SendWebFileDto,
  SendWebTextDto,
  UpdateWebSettingsDto,
} from './whatsapp-web.dto';

type JwtUser = { id: string; organizationId: string };

/**
 * WhatsApp магазина по QR (как WhatsApp Web / Green API).
 * Магазин = organizationId из JWT, никогда из запроса.
 */
@Controller('api/whatsapp/web')
@UseGuards(JwtAuthGuard, RolesGuard)
@UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
export class WhatsAppWebController {
  constructor(private readonly web: WhatsAppWebService) {}

  /** Запустить подключение: вернёт QR (qrDataUrl) или authorized. */
  @Post('connect')
  @Roles(UserRole.OWNER)
  connect(@CurrentUser() user: JwtUser) {
    return this.web.connect(user.organizationId);
  }

  /** Опрашивать раз в 2–3 секунды, пока state = qr: QR обновляется. */
  @Get('status')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  status(@CurrentUser() user: JwtUser) {
    return this.web.status(user.organizationId);
  }

  @Post('logout')
  @Roles(UserRole.OWNER)
  logout(@CurrentUser() user: JwtUser) {
    return this.web.logout(user.organizationId);
  }

  @Patch('settings')
  @Roles(UserRole.OWNER)
  settings(@CurrentUser() user: JwtUser, @Body() body: UpdateWebSettingsDto) {
    return this.web.setBotEnabled(user.organizationId, body.botEnabled);
  }

  @Get('chats')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  chats(
    @CurrentUser() user: JwtUser,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.web.listChats(
      user.organizationId,
      Math.min(Number(limit) || 50, 200),
      Number(offset) || 0,
    );
  }

  @Get('chats/:phone/messages')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  messages(
    @CurrentUser() user: JwtUser,
    @Param('phone') phone: string,
    @Query('limit') limit?: string,
    @Query('before') before?: string,
  ) {
    return this.web.chatMessages(
      user.organizationId,
      phone,
      Number(limit) || 50,
      before ? new Date(before) : undefined,
    );
  }

  @Post('chats/:phone/send')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  send(
    @CurrentUser() user: JwtUser,
    @Param('phone') phone: string,
    @Body() body: SendWebTextDto,
  ) {
    return this.web.sendFromManager(
      user.organizationId,
      user.id ?? null,
      phone,
      body.text,
    );
  }

  @Post('chats/:phone/send-file')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  sendFile(
    @CurrentUser() user: JwtUser,
    @Param('phone') phone: string,
    @Body() body: SendWebFileDto,
  ) {
    return this.web.sendFileFromManager(
      user.organizationId,
      user.id ?? null,
      phone,
      body,
    );
  }
}
