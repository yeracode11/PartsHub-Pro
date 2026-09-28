import { HttpException } from '@nestjs/common';
import { WhatsAppConnectionService } from './whatsapp-connection.service';
import { WhatsAppConnectionStatus } from './entities/whatsapp-connection.entity';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

describe('WhatsAppConnectionService', () => {
  function buildService(fallbackAccessToken: string) {
    const saved: Record<string, unknown> = {};
    const repo = {
      create: jest.fn((data: Record<string, unknown>) => ({ ...data })),
      save: jest.fn((entity: Record<string, unknown>) => {
        Object.assign(saved, entity, {
          id: 'conn-1',
          createdAt: new Date(),
          updatedAt: new Date(),
        });
        return Promise.resolve(saved);
      }),
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
    };
    const metaConfig = {
      fallbackAccessToken,
    } as unknown as MetaWhatsAppConfig;

    const service = new WhatsAppConnectionService(repo as any, metaConfig);
    return { service, repo, saved };
  }

  // TEST 1 + TEST 5: успешное создание без accessToken в body, токен не в response.
  it('creates connection without client accessToken, using env fallback; response has no accessToken', async () => {
    const { service } = buildService('env-secret-token');

    const result = await service.createForOrganization('org-1', {
      phoneNumberId: '1398564366663975',
      wabaId: '3483066548542535',
      displayName: 'AutoPlus Test WhatsApp',
    });

    expect(result).not.toHaveProperty('accessToken');
    expect((result as any).phoneNumberId).toBe('1398564366663975');
    expect((result as any).organizationId).toBe('org-1');
  });

  // TEST 2: organizationId передаётся через параметр (контроллер берёт его из JWT).
  it('persists the organizationId passed by the caller (JWT), not from connection data', async () => {
    const { service, repo } = buildService('env-secret-token');

    await service.createForOrganization('org-from-jwt', {
      phoneNumberId: '1398564366663975',
    });

    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({ organizationId: 'org-from-jwt' }),
    );
  });

  // TEST 4: без accessToken и без env fallback — создание не должно "тихо" пройти.
  it('throws if neither explicit accessToken nor META_WHATSAPP_ACCESS_TOKEN is configured', async () => {
    const { service, repo } = buildService('');

    await expect(
      service.createForOrganization('org-1', {
        phoneNumberId: '1398564366663975',
      }),
    ).rejects.toThrow(HttpException);

    expect(repo.save).not.toHaveBeenCalled();
  });

  // Явный accessToken (server-side/admin use) имеет приоритет над env.
  it('prefers explicit accessToken over env fallback when both are present', async () => {
    const { service, saved } = buildService('env-secret-token');

    await service.createForOrganization('org-1', {
      phoneNumberId: '1398564366663975',
      accessToken: 'explicit-token',
    });

    expect(saved.accessToken).toBe('explicit-token');
  });

  // TEST 3 + TEST 5: GET (findAllByOrganization) не возвращает accessToken.
  it('findAllByOrganization strips accessToken from every returned connection', async () => {
    const { service, repo } = buildService('env-secret-token');
    repo.find.mockResolvedValueOnce([
      {
        id: 'conn-1',
        organizationId: 'org-1',
        phoneNumberId: '1398564366663975',
        wabaId: '3483066548542535',
        phoneNumber: null,
        displayName: 'AutoPlus Test WhatsApp',
        accessToken: 'super-secret',
        status: WhatsAppConnectionStatus.ACTIVE,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);

    const result = await service.findAllByOrganization('org-1');

    expect(result).toHaveLength(1);
    expect(result[0]).not.toHaveProperty('accessToken');
  });

  it('maps duplicate phoneNumberId (unique violation) to a Conflict error', async () => {
    const { service, repo } = buildService('env-secret-token');
    repo.save.mockRejectedValueOnce({ code: '23505' });

    await expect(
      service.createForOrganization('org-2', {
        phoneNumberId: '1398564366663975',
      }),
    ).rejects.toThrow('уже подключён к другой организации');
  });
});
