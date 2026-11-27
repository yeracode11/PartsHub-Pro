import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SendLimiter, SendLimitError } from '../src/send-limiter.js';

function fakeClock() {
  let t = Date.UTC(2026, 10, 27, 10, 0, 0);
  const sleeps: number[] = [];
  return {
    now: () => t,
    sleep: async (ms: number) => {
      sleeps.push(ms);
      t += ms;
    },
    advance: (ms: number) => {
      t += ms;
    },
    sleeps,
  };
}

const limits = { minDelayMs: 3000, jitterMs: 0, maxPerMinute: 3, maxPerDay: 5, maxNewChatsPerDay: 2 };

test('first message goes out immediately, next ones wait the minimum delay', async () => {
  const c = fakeClock();
  const l = new SendLimiter(limits, c.now, c.sleep, () => 0);
  await l.schedule('a', false, async () => 1);
  await l.schedule('a', false, async () => 2);
  assert.deepEqual(c.sleeps, [3000]);
});

test('per-minute cap makes the 4th message wait for the window', async () => {
  const c = fakeClock();
  const l = new SendLimiter({ ...limits, minDelayMs: 0 }, c.now, c.sleep, () => 0);
  for (let i = 0; i < 4; i++) await l.schedule('a', false, async () => i);
  assert.equal(c.sleeps.at(-1), 60_000);
});

test('daily cap rejects with SendLimitError and resets next day', async () => {
  const c = fakeClock();
  const l = new SendLimiter({ ...limits, minDelayMs: 0, maxPerMinute: 100 }, c.now, c.sleep, () => 0);
  for (let i = 0; i < 5; i++) await l.schedule('a', false, async () => i);
  await assert.rejects(l.schedule('a', false, async () => 6), SendLimitError);
  assert.equal(l.remainingToday(), 0);
  c.advance(24 * 3600 * 1000);
  assert.equal(l.remainingToday(), 5);
});

test('new chats per day are capped, known chats are not', async () => {
  const c = fakeClock();
  const l = new SendLimiter({ ...limits, minDelayMs: 0, maxPerMinute: 100, maxPerDay: 100 }, c.now, c.sleep, () => 0);
  await l.schedule('n1', true, async () => 1);
  await l.schedule('n2', true, async () => 2);
  await assert.rejects(l.schedule('n3', true, async () => 3), (e: unknown) => (e as SendLimitError).code === 'new_chats_per_day');
  await l.schedule('n1', true, async () => 4); // уже писали сегодня
  await l.schedule('old', false, async () => 5);
});

test('a failed send does not block the queue', async () => {
  const c = fakeClock();
  const l = new SendLimiter(limits, c.now, c.sleep, () => 0);
  await assert.rejects(l.schedule('a', false, async () => { throw new Error('boom'); }));
  assert.equal(await l.schedule('a', false, async () => 'ok'), 'ok');
});
