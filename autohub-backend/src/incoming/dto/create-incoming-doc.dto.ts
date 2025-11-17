import { IsString, IsOptional, IsEnum, IsDateString, IsUUID, IsNumber, Min } from 'class-validator';
import { IncomingDocType } from '../entities/incoming-doc.entity';

export class CreateIncomingDocDto {
  @IsDateString()
  date: string;

  @IsOptional()
  @IsUUID()
  supplierId?: string;

  @IsOptional()
  @IsString()
  supplierName?: string;

  @IsEnum(IncomingDocType)
  type: IncomingDocType;

  @IsOptional()
  @IsString()
  warehouse?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString({ each: true })
  docPhotos?: string[];
}

