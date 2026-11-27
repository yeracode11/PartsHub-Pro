import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';

export class SendWebTextDto {
  @IsString()
  @MinLength(1)
  @MaxLength(4096)
  text: string;
}

export class SendWebFileDto {
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true })
  url: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  fileName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  mimetype?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  caption?: string;
}

export class UpdateWebSettingsDto {
  @IsBoolean()
  botEnabled: boolean;
}
