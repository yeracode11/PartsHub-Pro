import { Test, TestingModule } from '@nestjs/testing';
import { WhatsAppInboundService } from './whatsapp-inbound.service';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { MessageHistoryService } from './message-history.service';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

describe('WhatsAppInboundService', () => {
  let service: WhatsAppInboundService;
  const tenantResolver = { resolveByPhoneNumberId: jest.fn() };
  const historyService = {
    findByExternalMessageId: jest.fn(),
    createInbound: jest.fn(),
  };
  const metaWhatsAppService = { sendTextMessage: jest.fn() };
  const metaConfig = { fallbackAccessToken: 'server-token' };

  const textPayload = {
    object: 'whatsapp_business_account',
    entry: [
      {
        id: '3483066548542535',
        changes: [
          {
            field: 'messages',
            value: {
              metadata: { phone_number_id: '1398564366663975' },
              messages: [
                {
                  from: '77776442004',
                  id: 'wamid.dup',
                  type: 'text',
                  text: { body: 'камри 70 передние колодки есть?' },
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
        { provide: MetaWhatsAppService, useValue: metaWhatsAppService },
        { provide: MetaWhatsAppConfig, useValue: metaConfig },
      ],
    }).compile();

    service = module.get(WhatsAppInboundService);
  });

  it('does nothing for empty payload', async () => {
    await service.handleWebhookPayload({});

    expect(historyService.findByExternalMessageId).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('does nothing for status-only webhook', async () => {
    await service.handleWebhookPayload({
      object: 'whatsapp_business_account',
      entry: [
        {
          changes: [
            {
              field: 'messages',
              value: {
                metadata: { phone_number_id: '1398564366663975' },
                statuses: [{ id: 'wamid.x', status: 'delivered' }],
              },
            },
          ],
        },
      ],
    });

    expect(tenantResolver.resolveByPhoneNumberId).not.toHaveBeenCalled();
  });

  it('skips duplicate wamid without echo', async () => {
    historyService.findByExternalMessageId.mockResolvedValue({ id: 1 });

    await service.handleWebhookPayload(textPayload);

    expect(tenantResolver.resolveByPhoneNumberId).not.toHaveBeenCalled();
    expect(historyService.createInbound).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('warns and skips unknown phone_number_id', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue(null);

    await service.handleWebhookPayload(textPayload);

    expect(historyService.createInbound).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('saves inbound text, resolves tenant, sends echo', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: true,
    });
    metaWhatsAppService.sendTextMessage.mockResolvedValue({
      messageId: 'wamid.out',
    });

    await service.handleWebhookPayload(textPayload);

    expect(tenantResolver.resolveByPhoneNumberId).toHaveBeenCalledWith(
      '1398564366663975',
    );
    expect(historyService.createInbound).toHaveBeenCalledWith(
      expect.objectContaining({
        organizationId: 'org-1',
        whatsappConnectionId: 'conn-1',
        phone: '77776442004',
        externalMessageId: 'wamid.dup',
        messageType: 'text',
        message: 'камри 70 передние колодки есть?',
      }),
    );
    expect(metaWhatsAppService.sendTextMessage).toHaveBeenCalledWith(
      '1398564366663975',
      '77776442004',
      'Получил: камри 70 передние колодки есть?',
      'server-token',
    );
  });

  it('does not echo when createInbound reports duplicate (race)', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: false,
    });

    await service.handleWebhookPayload(textPayload);

    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('saves non-text without echo', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 11 },
      created: true,
    });

    await service.handleWebhookPayload({
      ...textPayload,
      entry: [
        {
          changes: [
            {
              field: 'messages',
              value: {
                metadata: { phone_number_id: '1398564366663975' },
                messages: [
                  {
                    from: '77776442004',
                    id: 'wamid.image',
                    type: 'image',
                  },
                ],
              },
            },
          ],
        },
      ],
    });

    expect(historyService.createInbound).toHaveBeenCalledWith(
      expect.objectContaining({ messageType: 'image', message: '[image]' }),
    );
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });
});
