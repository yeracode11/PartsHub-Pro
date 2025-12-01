import { Module } from '@nestjs/common';
import { AutoDataController } from './auto-data.controller';
import { AutoDataService } from './auto-data.service';

@Module({
  imports: [],
  controllers: [AutoDataController],
  providers: [AutoDataService],
  exports: [AutoDataService],
})
export class AutoDataModule {}


