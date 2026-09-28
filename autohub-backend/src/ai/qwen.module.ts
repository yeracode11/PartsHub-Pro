import { Module } from '@nestjs/common';
import { QwenConfig } from './qwen.config';
import { QwenService } from './qwen.service';

@Module({
  providers: [QwenConfig, QwenService],
  exports: [QwenService],
})
export class QwenModule {}
