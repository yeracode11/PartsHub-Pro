import { IsIn, IsNotEmpty, IsString, IsUUID, MinLength } from 'class-validator';

export class StartWhatsAppVerificationDto {
  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsString()
  @IsIn(['register', 'login', 'reset_password'])
  purpose: 'register' | 'login' | 'reset_password';
}

export class WhatsAppVerificationStatusDto {
  @IsUUID()
  verificationId: string;

  @IsString()
  @IsNotEmpty()
  secret: string;
}

export class WhatsAppLoginDto {
  @IsString()
  @IsNotEmpty()
  verificationToken: string;
}

export class WhatsAppResetPasswordDto {
  @IsString()
  @IsNotEmpty()
  verificationToken: string;

  @IsString()
  @MinLength(6, { message: 'Пароль должен быть не менее 6 символов' })
  newPassword: string;
}
