import { Test, TestingModule } from '@nestjs/testing';
import { WhatsAppMetaWebhookController } from './whatsapp-meta-webhook.controller';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { WhatsAppInboundService } from './whatsapp-inbound.service';

describe('WhatsAppMetaWebhookController', () => {
  let controller: WhatsAppMetaWebhookController;
  const inboundService = { handleWebhookPayload: jest.fn() };
  const metaConfig = {
    verifyToken: 'VALID',
    resolveVerifyToken: () => ({
      value: 'VALID',
      envKey: 'WHATSAPP_WEBHOOK_VERIFY_TOKEN' as const,
    }),
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

  function mockRes() {
    const send = jest.fn();
    const status = jest.fn().mockReturnValue({
      type: jest.fn().mockReturnValue({ send }),
    });
    return {
      res: { status, sendStatus: jest.fn() } as never,
      send,
      status,
    };
  }

  it('GET /webhooks/whatsapp returns 200 and challenge when token valid', () => {
    const { res, send, status } = mockRes();

    controller.verifyWebhook(
      {
        query: {
          'hub.mode': 'subscribe',
          'hub.verify_token': 'VALID',
          'hub.challenge': '123456',
        },
        originalUrl:
          '/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=VALID&hub.challenge=123456',
      } as never,
      res,
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(send).toHaveBeenCalledWith('123456');
  });

  it('GET returns 403 when no hub params (browser visit)', () => {
    const sendStatus = jest.fn();
    const res = { status: jest.fn(), sendStatus } as never;

    controller.verifyWebhook(
      { query: {}, originalUrl: '/webhooks/whatsapp' } as never,
      res,
    );

    expect(sendStatus).toHaveBeenCalledWith(403);
  });

  it('GET returns 403 when verify token invalid', () => {
    const sendStatus = jest.fn();
    const res = { status: jest.fn(), sendStatus } as never;

    controller.verifyWebhook(
      {
        query: {
          'hub.mode': 'subscribe',
          'hub.verify_token': 'WRONG',
          'hub.challenge': '123456',
        },
      } as never,
      res,
    );

    expect(sendStatus).toHaveBeenCalledWith(403);
  });

  it('POST delegates to inbound service and returns ok', async () => {
    inboundService.handleWebhookPayload.mockResolvedValue(undefined);

    const payload = {
      object: 'whatsapp_business_account',
      entry: [],
    };
    const result = await controller.receiveWebhook(payload);

    expect(inboundService.handleWebhookPayload).toHaveBeenCalledWith(payload);
    expect(result).toEqual({ status: 'ok' });
  });
});
