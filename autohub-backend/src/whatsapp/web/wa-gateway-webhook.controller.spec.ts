/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-explicit-any, @typescript-eslint/require-await, @typescript-eslint/no-unnecessary-type-assertion -- моки репозиториев в тестах */
import { createHmac } from 'crypto';
import { UnauthorizedException } from '@nestjs/common';
import { WaGatewayWebhookController } from './wa-gateway-webhook.controller';

function sign(body: string, secret: string) {
  return `sha256=${createHmac('sha256', secret).update(body).digest('hex')}`;
}

describe('WaGatewayWebhookController', () => {
  const event = {
    type: 'state',
    instanceId: 'x',
    state: 'authorized',
  } as const;
  const raw = JSON.stringify(event);

  it('accepts a correctly signed event', async () => {
    const web = { handleGatewayEvent: jest.fn() };
    const ctrl = new WaGatewayWebhookController(
      { webhookSecret: 's' } as any,
      web as any,
    );
    await ctrl.receive(
      event as any,
      {
        rawBody: Buffer.from(raw),
        headers: { 'x-vinly-signature': sign(raw, 's') },
      } as any,
    );
    expect(web.handleGatewayEvent).toHaveBeenCalledWith(event);
  });

  it('rejects a bad signature and an unset secret', async () => {
    const web = { handleGatewayEvent: jest.fn() };
    const bad = new WaGatewayWebhookController(
      { webhookSecret: 's' } as any,
      web as any,
    );
    await expect(
      bad.receive(
        event as any,
        {
          rawBody: Buffer.from(raw),
          headers: { 'x-vinly-signature': sign(raw, 'other') },
        } as any,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    const unset = new WaGatewayWebhookController(
      { webhookSecret: '' } as any,
      web as any,
    );
    await expect(
      unset.receive(
        event as any,
        {
          rawBody: Buffer.from(raw),
          headers: { 'x-vinly-signature': sign(raw, '') },
        } as any,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(web.handleGatewayEvent).not.toHaveBeenCalled();
  });
});
