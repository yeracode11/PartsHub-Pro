import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { PartialType } from '@nestjs/mapped-types';
import { FuelType, TransmissionType } from '../entities/vehicle.entity';

/**
 * Поля, которые клиент может задать при создании/правке автомобиля.
 * Пробег и даты ТО меняются только через /mileage и /service, поэтому
 * здесь их нет (ValidationPipe с whitelist отбрасывает лишние поля).
 */
export class CreateVehicleDto {
  @IsInt()
  customerId: number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  brand: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  model: string;

  @IsInt()
  @Min(1900)
  @Max(2100)
  year: number;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  color?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  plateNumber: string;

  /** Длину (17) проверяет сервис после нормализации пробелов. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  vin?: string;

  @IsOptional()
  @IsEnum(FuelType)
  fuelType?: FuelType;

  @IsOptional()
  @IsEnum(TransmissionType)
  transmission?: TransmissionType;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  engineVolume?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(5000)
  enginePower?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  currentMileage?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  photoUrl?: string;
}

export class UpdateVehicleDto extends PartialType(CreateVehicleDto) {}
