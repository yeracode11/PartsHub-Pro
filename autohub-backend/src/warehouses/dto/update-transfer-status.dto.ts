import { IsEnum } from 'class-validator';
import { TransferStatus } from '../entities/warehouse-transfer.entity';

export class UpdateTransferStatusDto {
  @IsEnum(TransferStatus)
  status: TransferStatus;
}

