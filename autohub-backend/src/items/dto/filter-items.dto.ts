import { IsOptional, IsString, IsNumber, IsBoolean, IsArray } from 'class-validator';
import { Type } from 'class-transformer';

export class FilterItemsDto {
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  categories?: string[];

  @IsOptional()
  @IsString()
  condition?: string; // new, used, refurbished

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  minPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  maxPrice?: number;

  @IsOptional()
  @IsString()
  warehouseId?: string;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  inStock?: boolean; // quantity > 0

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  syncedToB2C?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  minQuantity?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  maxQuantity?: number;
}

