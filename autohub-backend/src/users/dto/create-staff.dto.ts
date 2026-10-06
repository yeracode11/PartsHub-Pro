import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class CreateStaffDto {
  @IsString()
  @IsNotEmpty({ message: 'Укажите имя' })
  name: string;

  @IsString()
  @IsNotEmpty({ message: 'Укажите телефон' })
  phone: string;

  @IsString()
  @MinLength(6, { message: 'Пароль должен быть не менее 6 символов' })
  password: string;

  /** percent или hourly. По умолчанию процент. */
  payType?: string;

  /** Процент 0–100 или ставка за нормо-час. */
  payRate?: number;
}
