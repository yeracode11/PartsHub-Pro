import { createHmac } from 'crypto';
import { isValidMetaSignature } from './meta-webhook-signature.util';

describe('isValidMetaSignature', () => {
  const secret = 'app-secret';
  const body = Buffer.from('{"object":"whatsapp_business_account"}');
  const sign = (payload: Buffer, key = secret) =>
    `sha256=${createHmac('sha256', key).update(payload).digest('hex')}`;

  it('accepts a correct signature', () => {
    expect(isValidMetaSignature(body, sign(body), secret)).toBe(true);
  });

  it('rejects a signature made with another secret', () => {
    expect(isValidMetaSignature(body, sign(body, 'other'), secret)).toBe(false);
  });

  it('rejects a tampered body', () => {
    const tampered = Buffer.from('{"object":"tampered"}');
    expect(isValidMetaSignature(tampered, sign(body), secret)).toBe(false);
  });

  it('rejects missing or malformed headers', () => {
    expect(isValidMetaSignature(body, undefined, secret)).toBe(false);
    expect(isValidMetaSignature(body, 'sha1=abc', secret)).toBe(false);
    expect(isValidMetaSignature(body, 'sha256=zz', secret)).toBe(false);
    expect(isValidMetaSignature(undefined, sign(body), secret)).toBe(false);
  });
});
