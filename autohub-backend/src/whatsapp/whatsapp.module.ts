import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WhatsAppController } from './whatsapp.controller';
import { WhatsAppWebhookController } from './whatsapp-webhook.controller';
import { WhatsAppMetaWebhookController } from './whatsapp-meta-webhook.controller';
import { WhatsAppConnectionController } from './whatsapp-connection.controller';
import { WhatsAppService } from './whatsapp.service';
import { TemplatesController } from './templates.controller';
import { TemplatesService } from './templates.service';
import { MessageHistoryController } from './message-history.controller';
import { MessageHistoryService } from './message-history.service';
import { MessageTemplate } from './entities/message-template.entity';
import { MessageHistory } from './entities/message-history.entity';
import { WhatsAppConnection } from './entities/whatsapp-connection.entity';
import { WhatsAppMetaRecipientCache } from './entities/whatsapp-meta-recipient-cache.entity';
import { WhatsAppMetaRecipientCacheService } from './whatsapp-meta-recipient-cache.service';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { WhatsAppConnectionService } from './whatsapp-connection.service';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { WhatsAppInboundService } from './whatsapp-inbound.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MessageTemplate,
      MessageHistory,
      WhatsAppConnection,
      WhatsAppMetaRecipientCache,
    ]),
    VehiclesModule,
  ],
  controllers: [
    WhatsAppController,
    WhatsAppWebhookController,
    WhatsAppMetaWebhookController,
    WhatsAppConnectionController,
    TemplatesController,
    MessageHistoryController,
  ],
  providers: [
    WhatsAppService,
    TemplatesService,
    MessageHistoryService,
    MetaWhatsAppConfig,
    MetaWhatsAppService,
    WhatsAppConnectionService,
    WhatsAppTenantResolver,
    WhatsAppInboundService,
    WhatsAppMetaRecipientCacheService,
  ],
  exports: [
    WhatsAppService,
    TemplatesService,
    MessageHistoryService,
    MetaWhatsAppService,
    WhatsAppConnectionService,
    WhatsAppTenantResolver,
    WhatsAppInboundService,
  ],
})
export class WhatsAppModule {}
