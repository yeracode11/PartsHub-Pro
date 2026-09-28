import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

/**
 * POST /api/whatsapp/connections — Flutter отправляет только
 * phoneNumberId / wabaId / displayName. organizationId берётся из JWT
 * (@CurrentUser()), НЕ из этого DTO.
 *
 * accessToken — необязателен. Если не передан, WhatsAppConnectionService
 * использует META_WHATSAPP_ACCESS_TOKEN из server-side env
 * (см. MetaWhatsAppConfig.fallbackAccessToken). Flutter НИКОГДА не
 * заполняет это поле — оно оставлено только для потенциальных
 * server-side/admin вызовов с явным per-connection токеном.
 */
export class CreateWhatsAppConnectionDto {
  @IsString()
  @IsNotEmpty({ message: 'phoneNumberId обязателен' })
  phoneNumberId: string;

  @IsOptional()
  @IsString()
  wabaId?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  accessToken?: string;
}
