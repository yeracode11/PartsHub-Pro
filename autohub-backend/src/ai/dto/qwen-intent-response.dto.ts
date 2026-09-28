import {
  IsIn,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { QWEN_INTENTS, QWEN_LANGUAGES } from '../qwen-intent.types';

class QwenVehicleDto {
  @IsOptional()
  @IsString()
  brand?: string | null;

  @IsOptional()
  @IsString()
  model?: string | null;

  @IsOptional()
  @IsString()
  generation?: string | null;

  @IsOptional()
  year?: number | null;

  @IsOptional()
  @IsString()
  engine?: string | null;

  @IsOptional()
  @IsString()
  body?: string | null;
}

class QwenPartDto {
  @IsOptional()
  @IsString()
  name?: string | null;

  @IsOptional()
  @IsString()
  position?: string | null;
}

class QwenOrderDto {
  @IsOptional()
  @IsString()
  number?: string | null;
}

export class QwenIntentResponseDto {
  @IsString()
  @IsIn([...QWEN_INTENTS])
  intent!: string;

  @IsString()
  @IsIn([...QWEN_LANGUAGES])
  language!: string;

  @IsObject()
  @ValidateNested()
  @Type(() => QwenVehicleDto)
  vehicle!: QwenVehicleDto;

  @IsObject()
  @ValidateNested()
  @Type(() => QwenPartDto)
  part!: QwenPartDto;

  @IsObject()
  @ValidateNested()
  @Type(() => QwenOrderDto)
  order!: QwenOrderDto;
}
