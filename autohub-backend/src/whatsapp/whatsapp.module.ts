import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WhatsAppController } from './whatsapp.controller';
import { WhatsAppService } from './whatsapp.service';
import { TemplatesController } from './templates.controller';
import { TemplatesService } from './templates.service';
import { MessageHistoryController } from './message-history.controller';
import { MessageHistoryService } from './message-history.service';
import { MessageTemplate } from './entities/message-template.entity';
import { MessageHistory } from './entities/message-history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([MessageTemplate, MessageHistory])],
  controllers: [
    WhatsAppController,
    TemplatesController,
    MessageHistoryController,
  ],
  providers: [WhatsAppService, TemplatesService, MessageHistoryService],
  exports: [WhatsAppService, TemplatesService, MessageHistoryService],
})
export class WhatsAppModule {}

