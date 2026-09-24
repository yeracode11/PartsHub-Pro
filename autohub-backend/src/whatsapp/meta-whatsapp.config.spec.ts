import { ConfigService } from '@nestjs/config';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

describe('MetaWhatsAppConfig verify token', () => {
  it('uses only WHATSAPP_WEBHOOK_VERIFY_TOKEN', () => {
    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'WHATSAPP_WEBHOOK_VERIFY_TOKEN') return 'canonical-token';
        if (key === 'META_WHATSAPP_VERIFY_TOKEN') return 'meta-token';
        if (key === 'WHATSAPP_VERIFY_TOKEN') return 'legacy-token';
        return undefined;
      }),
    } as unknown as ConfigService;

    const config = new MetaWhatsAppConfig(configService);
    expect(config.verifyToken).toBe('canonical-token');
    expect(config.resolveVerifyToken().envKey).toBe('WHATSAPP_WEBHOOK_VERIFY_TOKEN');
  });

  it('returns empty when WHATSAPP_WEBHOOK_VERIFY_TOKEN unset', () => {
    const configService = {
      get: jest.fn(() => undefined),
    } as unknown as ConfigService;

    const config = new MetaWhatsAppConfig(configService);
    expect(config.verifyToken).toBe('');
    expect(config.resolveVerifyToken().envKey).toBeNull();
  });
});
