import { WhatsAppTenantResolver } from './whatsapp-tenant-resolver.service';
import { WhatsAppConnectionService } from './whatsapp-connection.service';

describe('WhatsAppTenantResolver', () => {
  it('resolveByPhoneNumberId returns organization from connection', async () => {
    const connectionService = {
      findByPhoneNumberId: jest.fn().mockResolvedValue({
        id: 'conn-1',
        organizationId: 'org-abc',
        phoneNumberId: '1398564366663975',
      }),
    } as unknown as WhatsAppConnectionService;

    const resolver = new WhatsAppTenantResolver(connectionService);
    const result = await resolver.resolveByPhoneNumberId('1398564366663975');

    expect(result?.organizationId).toBe('org-abc');
    expect(result?.connection.id).toBe('conn-1');
  });

  it('returns null when connection missing', async () => {
    const connectionService = {
      findByPhoneNumberId: jest.fn().mockResolvedValue(null),
    } as unknown as WhatsAppConnectionService;

    const resolver = new WhatsAppTenantResolver(connectionService);
    const result = await resolver.resolveByPhoneNumberId('unknown');

    expect(result).toBeNull();
  });
});
