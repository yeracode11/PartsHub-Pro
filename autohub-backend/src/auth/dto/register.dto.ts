import { IsIn, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(6, { message: 'Пароль должен быть не менее 6 символов' })
  password: string;

  @IsString()
  @IsNotEmpty({ message: 'Укажите имя' })
  name: string;

  @IsString()
  @IsNotEmpty({ message: 'Укажите название организации' })
  organizationName: string;

  @IsString()
  @IsIn(['owner'], { message: 'Регистрация доступна только владельцу' })
  role: 'owner';

  @IsString()
  @IsOptional()
  businessType?: string;
}
