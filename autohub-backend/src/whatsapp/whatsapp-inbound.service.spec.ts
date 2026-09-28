import { Test, TestingModule } from '@nestjs/testing';
import { WhatsAppInboundService } from './whatsapp-inbound.service';
import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { MessageHistoryService } from './message-history.service';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { QwenService } from '../ai/qwen.service';
import { StockService } from '../inventory/stock.service';

describe('WhatsAppInboundService', () => {
  let service: WhatsAppInboundService;
  const tenantResolver = { resolveByPhoneNumberId: jest.fn() };
  const historyService = {
    findByExternalMessageId: jest.fn(),
    createInbound: jest.fn(),
  };
  const metaWhatsAppService = { sendTextMessage: jest.fn() };
  const metaConfig = { fallbackAccessToken: 'server-token' };
  const qwenService = { parseIntent: jest.fn() };
  const stockService = { buildCheckStockReply: jest.fn() };

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
        { provide: QwenService, useValue: qwenService },
        { provide: StockService, useValue: stockService },
      ],
    }).compile();

    service = module.get(WhatsAppInboundService);
  });

  it('does nothing for empty payload', async () => {
    await service.handleWebhookPayload({});

    expect(historyService.findByExternalMessageId).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('does nothing for status-only webhook (Qwen not called)', async () => {
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
    expect(qwenService.parseIntent).not.toHaveBeenCalled();
  });

  it('skips duplicate wamid without echo', async () => {
    historyService.findByExternalMessageId.mockResolvedValue({ id: 1 });

    await service.handleWebhookPayload(textPayload);

    expect(tenantResolver.resolveByPhoneNumberId).not.toHaveBeenCalled();
    expect(historyService.createInbound).not.toHaveBeenCalled();
    expect(qwenService.parseIntent).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('warns and skips unknown phone_number_id', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue(null);

    await service.handleWebhookPayload(textPayload);

    expect(historyService.createInbound).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('check_stock sends stock reply via MetaWhatsAppService', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1', accessToken: 'conn-token' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: true,
    });
    metaWhatsAppService.sendTextMessage.mockResolvedValue({
      messageId: 'wamid.out',
    });
    qwenService.parseIntent.mockResolvedValue({
      intent: 'check_stock',
      language: 'ru',
      vehicle: {
        brand: 'Toyota',
        model: 'Camry',
        generation: '70',
        year: null,
        engine: null,
        body: null,
      },
      part: { name: 'brake_pad', position: 'front' },
      order: { number: null },
    });
    stockService.buildCheckStockReply.mockResolvedValue(
      'Да, нашли:\nToyota Camry 70\nПередние тормозные колодки\nВ наличии: 2 комплекта.',
    );

    await service.handleWebhookPayload(textPayload);

    expect(qwenService.parseIntent).toHaveBeenCalledWith(
      'камри 70 передние колодки есть?',
    );

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
    expect(stockService.buildCheckStockReply).toHaveBeenCalledWith(
      'org-1',
      expect.objectContaining({ intent: 'check_stock' }),
    );
    expect(metaWhatsAppService.sendTextMessage).toHaveBeenCalledWith(
      '1398564366663975',
      '77776442004',
      expect.stringContaining('Да, нашли'),
      'server-token',
    );
  });

  it('unknown intent falls back to echo', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1', accessToken: 'conn-token' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: true,
    });
    qwenService.parseIntent.mockResolvedValue({
      intent: 'unknown',
      language: 'ru',
      vehicle: {
        brand: null,
        model: null,
        generation: null,
        year: null,
        engine: null,
        body: null,
      },
      part: { name: null, position: null },
      order: { number: null },
    });
    metaWhatsAppService.sendTextMessage.mockResolvedValue({ messageId: 'x' });

    await service.handleWebhookPayload(textPayload);

    expect(stockService.buildCheckStockReply).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      'Получил: камри 70 передние колодки есть?',
      expect.any(String),
    );
  });

  it('uses connection token when env token empty', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        WhatsAppInboundService,
        { provide: WhatsAppTenantResolver, useValue: tenantResolver },
        { provide: MessageHistoryService, useValue: historyService },
        { provide: MetaWhatsAppService, useValue: metaWhatsAppService },
        { provide: MetaWhatsAppConfig, useValue: { fallbackAccessToken: '' } },
        { provide: QwenService, useValue: qwenService },
        { provide: StockService, useValue: stockService },
      ],
    }).compile();
    const localService = moduleRef.get(WhatsAppInboundService);

    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1', accessToken: 'conn-token' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: true,
    });
    metaWhatsAppService.sendTextMessage.mockResolvedValue({ messageId: 'x' });

    await localService.handleWebhookPayload(textPayload);

    expect(metaWhatsAppService.sendTextMessage).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      expect.any(String),
      'conn-token',
    );
  });

  it('does not echo when createInbound reports duplicate (race)', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1', accessToken: 'conn-token' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: false,
    });

    await service.handleWebhookPayload(textPayload);

    expect(qwenService.parseIntent).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('still sends echo when Qwen returns null', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1', accessToken: 'conn-token' },
    });
    historyService.createInbound.mockResolvedValue({
      record: { id: 10 },
      created: true,
    });
    qwenService.parseIntent.mockResolvedValue(null);
    metaWhatsAppService.sendTextMessage.mockResolvedValue({ messageId: 'out' });
    stockService.buildCheckStockReply.mockReset();

    await service.handleWebhookPayload(textPayload);

    expect(qwenService.parseIntent).toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).toHaveBeenCalled();
  });

  it('saves non-text without echo or Qwen', async () => {
    historyService.findByExternalMessageId.mockResolvedValue(null);
    tenantResolver.resolveByPhoneNumberId.mockResolvedValue({
      organizationId: 'org-1',
      connection: { id: 'conn-1', accessToken: 'conn-token' },
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
    expect(qwenService.parseIntent).not.toHaveBeenCalled();
    expect(metaWhatsAppService.sendTextMessage).not.toHaveBeenCalled();
  });
});
