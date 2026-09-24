import { parseMetaHubVerifyQuery } from './meta-webhook-verify.util';

describe('parseMetaHubVerifyQuery', () => {
  it('reads dotted hub query keys', () => {
    const parsed = parseMetaHubVerifyQuery({
      'hub.mode': 'subscribe',
      'hub.verify_token': 'VALID',
      'hub.challenge': '123456',
    });

    expect(parsed).toEqual({
      mode: 'subscribe',
      verifyToken: 'VALID',
      challenge: '123456',
    });
  });

  it('reads hub params from originalUrl when query object is empty', () => {
    const parsed = parseMetaHubVerifyQuery(
      {},
      '/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=VALID&hub.challenge=123456',
    );

    expect(parsed).toEqual({
      mode: 'subscribe',
      verifyToken: 'VALID',
      challenge: '123456',
    });
  });

  it('reads nested hub object query keys', () => {
    const parsed = parseMetaHubVerifyQuery({
      hub: {
        mode: 'subscribe',
        verify_token: 'VALID',
        challenge: '123456',
      },
    });

    expect(parsed.mode).toBe('subscribe');
    expect(parsed.verifyToken).toBe('VALID');
    expect(parsed.challenge).toBe('123456');
  });
});
