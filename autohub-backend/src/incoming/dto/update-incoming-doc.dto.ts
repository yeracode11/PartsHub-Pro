import { IsString, IsOptional, IsEnum, IsDateString, IsUUID } from 'class-validator';
import { IncomingDocStatus, IncomingDocType } from '../entities/incoming-doc.entity';

export class UpdateIncomingDocDto {
  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsUUID()
  supplierId?: string;

  @IsOptional()
  @IsString()
  supplierName?: string;

  @IsOptional()
  @IsEnum(IncomingDocType)
  type?: IncomingDocType;

  @IsOptional()
  @IsString()
  warehouse?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString({ each: true })
  docPhotos?: string[];

  @IsOptional()
  @IsEnum(IncomingDocStatus)
  status?: IncomingDocStatus;
}

