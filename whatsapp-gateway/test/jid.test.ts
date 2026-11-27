import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isIgnoredChat, isValidInstanceId, normalizePhone, phoneFromKey } from '../src/jid.js';

test('normalizePhone: KZ formats', () => {
  assert.equal(normalizePhone('+7 (701) 123-45-67'), '77011234567');
  assert.equal(normalizePhone('87011234567'), '77011234567');
  assert.equal(normalizePhone('123'), null);
  assert.equal(normalizePhone(undefined), null);
});

test('instance id must be a uuid (no path traversal)', () => {
  assert.ok(isValidInstanceId('3f2b6a1e-1c2d-4e5f-8a9b-0c1d2e3f4a5b'));
  assert.ok(!isValidInstanceId('../etc'));
  assert.ok(!isValidInstanceId('abc'));
});

test('groups, statuses and channels are ignored', () => {
  assert.ok(isIgnoredChat('120363@g.us'));
  assert.ok(isIgnoredChat('status@broadcast'));
  assert.ok(isIgnoredChat('123@newsletter'));
  assert.ok(!isIgnoredChat('77011234567@s.whatsapp.net'));
});

test('phoneFromKey prefers the phone jid, falls back from LID to remoteJidAlt', () => {
  assert.equal(phoneFromKey({ remoteJid: '77011234567@s.whatsapp.net' }), '77011234567');
  assert.equal(
    phoneFromKey({ remoteJid: '1234567890@lid', remoteJidAlt: '77011234567@s.whatsapp.net' }),
    '77011234567',
  );
  assert.equal(phoneFromKey({ remoteJid: '1234567890@lid' }), null);
});
