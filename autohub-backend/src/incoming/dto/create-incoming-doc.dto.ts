import { IsString, IsOptional, IsEnum, IsDateString, IsUUID, IsNumber, Min, ValidateIf } from 'class-validator';
import { IncomingDocType } from '../entities/incoming-doc.entity';

export class CreateIncomingDocDto {
  @IsDateString()
  date: string;

  @ValidateIf((o) => o.supplierId !== null && o.supplierId !== undefined && o.supplierId !== '')
  @IsUUID(undefined, { message: 'supplierId must be a valid UUID' })
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

