import {
  IsString,
  IsOptional,
  IsNumber,
  IsInt,
  Min,
  IsArray,
  MaxLength,
} from 'class-validator';

export class CreateIncomingItemDto {
  @IsOptional()
  @IsInt()
  itemId?: number; // Для новых запчастей - ID существующего товара

  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  carBrand?: string;

  @IsOptional()
  @IsString()
  carModel?: string;

  @IsOptional()
  @IsString()
  vin?: string;

  @IsOptional()
  @IsString()
  condition?: string;

  @IsInt()
  @Min(1)
  quantity: number;

  @IsNumber()
  @Min(0)
  purchasePrice: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  salePrice?: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  oem?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  barcode?: string;

  @IsOptional()
  @IsString()
  warehouseCell?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  photos?: string[];

  @IsOptional()
  @IsString()
  sku?: string;
}
