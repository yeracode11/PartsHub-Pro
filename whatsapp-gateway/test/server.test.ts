import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { pino } from 'pino';
import { createServer } from '../src/server.js';
import { signBody } from '../src/webhook.js';
import type { InstanceManager } from '../src/manager.js';

const ID = '3f2b6a1e-1c2d-4e5f-8a9b-0c1d2e3f4a5b';

async function withServer(manager: Partial<InstanceManager>, fn: (base: string) => Promise<void>) {
  const app = createServer(manager as InstanceManager, 'secret-key', pino({ level: 'silent' }));
  const server = app.listen(0);
  const { port } = server.address() as AddressInfo;
  try {
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    server.close();
  }
}

test('requests without the api key are rejected', async () => {
  await withServer({}, async (base) => {
    const res = await fetch(`${base}/instances/${ID}`);
    assert.equal(res.status, 401);
    const health = await fetch(`${base}/health`);
    assert.equal(health.status, 200);
  });
});

test('invalid instance id is rejected before touching the manager', async () => {
  await withServer({}, async (base) => {
    const res = await fetch(`${base}/instances/..%2Fetc`, { headers: { 'x-api-key': 'secret-key' } });
    assert.equal(res.status, 400);
  });
});

test('send-text validates input and maps errors to http codes', async () => {
  const { SendLimitError } = await import('../src/send-limiter.js');
  const inst = {
    sendText: async () => {
      throw new SendLimitError('limit', 'per_day');
    },
  };
  await withServer({ get: () => inst as never }, async (base) => {
    const headers = { 'x-api-key': 'secret-key', 'content-type': 'application/json' };
    const bad = await fetch(`${base}/instances/${ID}/send-text`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ phone: '1', text: '' }),
    });
    assert.equal(bad.status, 400);
    const limited = await fetch(`${base}/instances/${ID}/send-text`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ phone: '+7 701 123 45 67', text: 'Здравствуйте' }),
    });
    assert.equal(limited.status, 429);
  });
});

test('webhook signature matches the backend format', () => {
  assert.match(signBody('{"a":1}', 's'), /^sha256=[0-9a-f]{64}$/);
});
