import { IsString, IsInt, IsOptional, IsUUID, Min } from 'class-validator';

export class CreateTransferDto {
  @IsUUID()
  fromWarehouseId: string;

  @IsUUID()
  toWarehouseId: string;

  @IsInt()
  itemId: number;

  @IsInt()
  @Min(1)
  quantity: number;

  @IsString()
  @IsOptional()
  notes?: string;
}

