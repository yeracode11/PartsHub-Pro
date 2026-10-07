import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PartialType } from '@nestjs/mapped-types';
import {
  DonorDrivetrain,
  DonorTransmission,
} from '../entities/donor-vehicle.entity';

export class CreateDonorDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  brand: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  model: string;

  @IsOptional()
  @IsInt()
  makeId?: number;

  @IsOptional()
  @IsInt()
  modelId?: number;

  @IsOptional()
  @IsInt()
  generationId?: number;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  generation?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  body?: string;

  @IsOptional()
  @IsInt()
  @Min(1950)
  @Max(2100)
  year?: number;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  vin?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  engine?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(0.1)
  @Max(20)
  engineVolume?: number;

  @IsOptional()
  @IsEnum(DonorTransmission)
  transmission?: DonorTransmission;

  @IsOptional()
  @IsEnum(DonorDrivetrain)
  drivetrain?: DonorDrivetrain;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  color?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  mileage?: number;

  @IsNumber()
  @Min(0)
  purchasePrice: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  deliveryCost?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  dismantlingCost?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  otherCosts?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  scrapIncome?: number;

  @IsOptional()
  @IsDateString()
  purchaseDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  source?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  notes?: string;

  /** Куплен или уже стоит на площадке. По умолчанию — куплен. */
  @IsOptional()
  @IsString()
  status?: string;
}

export class UpdateDonorDto extends PartialType(CreateDonorDto) {
  @IsOptional()
  @IsDateString()
  dismantlingStartDate?: string | null;

  @IsOptional()
  @IsDateString()
  dismantlingEndDate?: string | null;
}

export class RemoveDonorPhotoDto {
  @IsString()
  @IsNotEmpty()
  imageUrl: string;
}

export class DonorPartDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @IsNumber()
  @Min(0)
  price: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  quantity?: number;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  condition?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  warehouseCell?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  sku?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  oem?: string;

  @IsOptional()
  @IsString()
  description?: string;
}

export class AddDonorPartsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => DonorPartDto)
  parts: DonorPartDto[];
}
