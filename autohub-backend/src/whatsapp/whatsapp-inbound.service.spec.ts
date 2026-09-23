import { Test, TestingModule } from '@nestjs/testing';
import { WhatsAppInboundService } from './whatsapp-inbound.service';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { MessageHistoryService } from './message-history.service';

describe('WhatsAppInboundService', () => {
  let service: WhatsAppInboundService;
  const tenantResolver = { resolveByPhoneNumberId: jest.fn() };
  const historyService = {
    findByExternalMessageId: jest.fn(),
    createInbound: jest.fn(),
  };

  const payload = {
    object: 'whatsapp_business_account',
    entry: [
      {
        id: 'waba',
        changes: [
          {
            field: 'messages',
            value: {
              metadata: { phone_number_id: '1398564366663975' },
              messages: [
                {
                  from: '77770001122',
                  id: 'wamid.dup',
                  type: 'text',
                  text: { body: 'hello' },
                },
              ],
            },
          },
        ],
      },
    ],
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WhatsAppInboundService,
        { provide: WhatsAppTenantResolver, useValue: tenantResolver },
        { provide: MessageHistoryService, useValue: historyService },
      ],
    }).compile();

    service = module.get(WhatsAppInboundService);
  });

  it('skips duplicate message_id', async () => {
    historyService.findByExternalMessageId.mockResolvedValue({ id: 1 });

    await service.handleWebhookPayload(payload);

    expect(tenantResolver.resolveByPhoneNumberId).not.toHaveBeenCalled();
    expect(historyService.createInbound).not.toHaveBeenCalled();
  });

  it('warns and skips unknown phone_number_id', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue(null);

    await service.handleWebhookPayload(payload);

    expect(historyService.createInbound).not.toHaveBeenCalled();
  });

  it('saves inbound text for resolved tenant', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1' },
    });

    await service.handleWebhookPayload(payload);

    expect(historyService.createInbound).toHaveBeenCalledWith(
      expect.objectContaining({
        organizationId: 'org-1',
        whatsappConnectionId: 'conn-1',
        externalMessageId: 'wamid.dup',
        message: 'hello',
      }),
    );
  });
});
