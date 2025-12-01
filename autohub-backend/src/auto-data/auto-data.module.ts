import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { AutoDataController } from './auto-data.controller';
import { AutoDataService } from './auto-data.service';

@Module({
  imports: [HttpModule],
  controllers: [AutoDataController],
  providers: [AutoDataService],
  exports: [AutoDataService],
})
export class AutoDataModule {}


