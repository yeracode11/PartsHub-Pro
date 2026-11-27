/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-explicit-any, @typescript-eslint/require-await, @typescript-eslint/no-unnecessary-type-assertion -- моки репозиториев в тестах */
import { MessageDirection } from '../entities/message-history.entity';
import {
  WhatsAppWebService,
  normalizeChatPhone,
  webExternalId,
} from './whatsapp-web.service';

const ORG = '3f2b6a1e-1c2d-4e5f-8a9b-0c1d2e3f4a5b';

function makeService(
  opts: { botEnabled?: boolean; managerActiveCount?: number } = {},
) {
  const instanceRow = {
    organizationId: ORG,
    state: 'authorized',
    phone: '77010000000',
    reason: null,
    botEnabled: opts.botEnabled ?? true,
  };
  const saved: any[] = [];
  const instances = {
    findOne: jest.fn().mockResolvedValue(instanceRow),
    save: jest.fn().mockImplementation(async (r) => r),
    create: jest.fn().mockImplementation((r) => r),
    update: jest.fn(),
  };
  const qb: any = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getCount: jest.fn().mockResolvedValue(opts.managerActiveCount ?? 0),
  };
  const history = {
    findOne: jest
      .fn()
      .mockImplementation(
        async ({ where }) =>
          saved.find((s) => s.externalMessageId === where.externalMessageId) ??
          null,
      ),
    create: jest.fn().mockImplementation((r) => r),
    save: jest.fn().mockImplementation(async (r) => {
      saved.push(r);
      return r;
    }),
    createQueryBuilder: jest.fn().mockReturnValue(qb),
  };
  const gateway = {
    sendText: jest.fn().mockResolvedValue({ messageId: 'OUT1' }),
  };
  const config = { botPauseAfterManagerMinutes: 120 };
  const inbound = {
    generateBotReply: jest.fn().mockResolvedValue('Есть в наличии: бампер'),
  };
  const service = new WhatsAppWebService(
    instances as any,
    history as any,
    gateway as any,
    config as any,
    inbound as any,
  );
  return { service, instances, history, gateway, inbound, saved, instanceRow };
}

const flush = () => new Promise((r) => setImmediate(r));

const customerMessage = {
  type: 'message' as const,
  instanceId: ORG,
  messageId: 'IN1',
  phone: '77011234567',
  fromMe: false,
  pushName: 'Айдар',
  timestamp: 1795000000,
  messageType: 'text',
  text: 'есть бампер на камри 50?',
};

describe('WhatsAppWebService', () => {
  it('saves an inbound customer message once and the bot replies', async () => {
    const { service, saved, gateway, inbound } = makeService();
    await service.handleGatewayEvent(customerMessage);
    await service.handleGatewayEvent(customerMessage); // повтор вебхука
    await flush();
    await flush();

    const inboundRows = saved.filter(
      (s) => s.direction === MessageDirection.INBOUND,
    );
    expect(inboundRows).toHaveLength(1);
    expect(inboundRows[0]).toMatchObject({
      organizationId: ORG,
      phone: '77011234567',
      externalMessageId: webExternalId(ORG, 'IN1'),
      metadata: expect.objectContaining({
        channel: 'web',
        source: 'customer',
        pushName: 'Айдар',
      }),
    });
    expect(inbound.generateBotReply).toHaveBeenCalledTimes(1);
    expect(gateway.sendText).toHaveBeenCalledWith(
      ORG,
      '77011234567',
      'Есть в наличии: бампер',
    );
    const botRow = saved.find((s) => s.metadata?.source === 'bot');
    expect(botRow).toMatchObject({
      direction: MessageDirection.OUTBOUND,
      externalMessageId: webExternalId(ORG, 'OUT1'),
    });
  });

  it('bot stays silent when disabled', async () => {
    const { service, gateway } = makeService({ botEnabled: false });
    await service.handleGatewayEvent(customerMessage);
    await flush();
    expect(gateway.sendText).not.toHaveBeenCalled();
  });

  it('bot stays silent while a manager is active in the chat', async () => {
    const { service, gateway, inbound } = makeService({
      managerActiveCount: 1,
    });
    await service.handleGatewayEvent(customerMessage);
    await flush();
    await flush();
    expect(inbound.generateBotReply).not.toHaveBeenCalled();
    expect(gateway.sendText).not.toHaveBeenCalled();
  });

  it('messages the shop sends from its phone are saved as outbound and never trigger the bot', async () => {
    const { service, saved, gateway } = makeService();
    await service.handleGatewayEvent({
      ...customerMessage,
      messageId: 'ME1',
      fromMe: true,
    });
    await flush();
    expect(saved[0]).toMatchObject({
      direction: MessageDirection.OUTBOUND,
      metadata: expect.objectContaining({ source: 'phone' }),
    });
    expect(gateway.sendText).not.toHaveBeenCalled();
  });

  it('state events update the instance; logout clears the phone', async () => {
    const { service, instanceRow } = makeService();
    await service.handleGatewayEvent({
      type: 'state',
      instanceId: ORG,
      state: 'logged_out',
      reason: 'banned',
    });
    expect(instanceRow).toMatchObject({
      state: 'logged_out',
      phone: null,
      reason: 'banned',
    });
  });

  it('normalizes KZ phone numbers and rejects junk', () => {
    expect(normalizeChatPhone('8 (701) 123-45-67')).toBe('77011234567');
    expect(() => normalizeChatPhone('12')).toThrow();
  });
});
