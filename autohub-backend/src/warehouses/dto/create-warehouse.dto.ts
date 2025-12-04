import { IsString, IsOptional, IsBoolean, IsNotEmpty } from 'class-validator';

export class CreateWarehouseDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @IsOptional()
  contactPerson?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

