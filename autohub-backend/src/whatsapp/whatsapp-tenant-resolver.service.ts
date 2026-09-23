import { Injectable } from '@nestjs/common';
import { WhatsAppConnectionService } from './whatsapp-connection.service';
import { WhatsAppConnection } from './entities/whatsapp-connection.entity';

export interface ResolvedWhatsAppTenant {
  connection: WhatsAppConnection;
  organizationId: string;
}

@Injectable()
export class WhatsAppTenantResolver {
  constructor(
    private readonly connectionService: WhatsAppConnectionService,
  ) {}

  async resolveByPhoneNumberId(
    phoneNumberId: string,
  ): Promise<ResolvedWhatsAppTenant | null> {
    const connection =
      await this.connectionService.findByPhoneNumberId(phoneNumberId);
    if (!connection) {
      return null;
    }

    return {
      connection,
      organizationId: connection.organizationId,
    };
  }
}
