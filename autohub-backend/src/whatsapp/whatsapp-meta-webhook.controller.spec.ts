import { Test, TestingModule } from '@nestjs/testing';
import { WhatsAppMetaWebhookController } from './whatsapp-meta-webhook.controller';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { WhatsAppInboundService } from './whatsapp-inbound.service';

describe('WhatsAppMetaWebhookController', () => {
  let controller: WhatsAppMetaWebhookController;
  const inboundService = { handleWebhookPayload: jest.fn() };
  const metaConfig = {
    verifyToken: 'valid-token',
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [WhatsAppMetaWebhookController],
      providers: [
        { provide: MetaWhatsAppConfig, useValue: metaConfig },
        { provide: WhatsAppInboundService, useValue: inboundService },
      ],
    }).compile();

    controller = module.get(WhatsAppMetaWebhookController);
  });

  it('GET verify returns challenge when token matches', () => {
    const send = jest.fn();
    const status = jest.fn().mockReturnValue({ type: jest.fn().mockReturnValue({ send }) });
    const res = { status, sendStatus: jest.fn() };

    controller.verifyWebhook(
      'subscribe',
      'valid-token',
      'challenge-xyz',
      res as never,
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(send).toHaveBeenCalledWith('challenge-xyz');
  });

  it('GET verify returns 403 when token invalid', () => {
    const res = {
      status: jest.fn(),
      sendStatus: jest.fn().mockReturnValue(undefined),
    };

    controller.verifyWebhook('subscribe', 'bad', 'c', res as never);

    expect(res.sendStatus).toHaveBeenCalledWith(403);
  });

  it('POST delegates to inbound service and returns ok', async () => {
    inboundService.handleWebhookPayload.mockResolvedValue(undefined);

    const result = await controller.receiveWebhook({
      object: 'whatsapp_business_account',
      entry: [],
    });

    expect(inboundService.handleWebhookPayload).toHaveBeenCalled();
    expect(result).toEqual({ status: 'ok' });
  });
});
