import { HttpException } from '@nestjs/common';
import { WhatsAppConnectionController } from './whatsapp-connection.controller';
import { WhatsAppConnectionService } from './whatsapp-connection.service';

describe('WhatsAppConnectionController', () => {
  function buildController() {
    const connectionService = {
      createForOrganization: jest.fn().mockResolvedValue({ id: 'conn-1' }),
      findAllByOrganization: jest.fn().mockResolvedValue([]),
    } as unknown as WhatsAppConnectionService;

    const controller = new WhatsAppConnectionController(connectionService);
    return { controller, connectionService };
  }

  // TEST 2: organizationId — только из @CurrentUser() (JWT), не из body.
  it('create() uses organizationId from @CurrentUser(), ignoring any organizationId in body', async () => {
    const { controller, connectionService } = buildController();

    await controller.create(
      { organizationId: 'org-from-jwt' },
      {
        phoneNumberId: '1398564366663975',
        wabaId: '3483066548542535',
        displayName: 'AutoPlus Test WhatsApp',
        // Попытка подделать tenant через body — контроллер должен игнорировать это поле.
        organizationId: 'org-attacker',
      } as any,
    );

    expect(connectionService.createForOrganization).toHaveBeenCalledWith(
      'org-from-jwt',
      expect.objectContaining({
        phoneNumberId: '1398564366663975',
        wabaId: '3483066548542535',
        displayName: 'AutoPlus Test WhatsApp',
      }),
    );
  });

  // TEST 1: body без accessToken — контроллер не требует его и не блокирует запрос.
  it('create() does not require accessToken in body', async () => {
    const { controller, connectionService } = buildController();

    await controller.create(
      { organizationId: 'org-1' },
      {
        phoneNumberId: '1398564366663975',
        wabaId: '3483066548542535',
        displayName: 'AutoPlus Test WhatsApp',
      } as any,
    );

    const callArgs = (connectionService.createForOrganization as jest.Mock)
      .mock.calls[0][1];
    expect(callArgs.accessToken).toBeUndefined();
  });

  it('create() rejects missing phoneNumberId with 400', () => {
    const { controller } = buildController();

    expect(() =>
      controller.create({ organizationId: 'org-1' }, {} as any),
    ).toThrow(HttpException);
  });

  // TEST 2 (GET): organizationId для списка тоже из JWT.
  it('list() uses organizationId from @CurrentUser()', async () => {
    const { controller, connectionService } = buildController();

    await controller.list({ organizationId: 'org-from-jwt' });

    expect(connectionService.findAllByOrganization).toHaveBeenCalledWith(
      'org-from-jwt',
    );
  });
});
