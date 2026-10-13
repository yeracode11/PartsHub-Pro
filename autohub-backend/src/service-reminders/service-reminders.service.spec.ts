import { BadRequestException } from '@nestjs/common';
import { ServiceRemindersService } from './service-reminders.service';

describe('ServiceRemindersService', () => {
  const settingsRepository = {
    findOne: jest.fn(),
    find: jest.fn(),
    save: jest.fn(async (v) => v),
    create: jest.fn((v) => v),
  };
  const logRepository = { findOne: jest.fn(), save: jest.fn(), create: jest.fn((v) => v) };
  const vehicleRepository = { createQueryBuilder: jest.fn() };
  const connectionRepository = { findOne: jest.fn(), find: jest.fn() };
  const meta = {
    getTemplateStatus: jest.fn(),
    createUtilityTemplate: jest.fn(),
    sendTemplateMessage: jest.fn(),
  };
  const service = new ServiceRemindersService(
    settingsRepository as any,
    logRepository as any,
    vehicleRepository as any,
    connectionRepository as any,
    meta as any,
  );
  const connection = {
    id: 'conn-1',
    organizationId: 'org-1',
    phoneNumberId: 'PN1',
    wabaId: 'WABA1',
    accessToken: 'token',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    connectionRepository.findOne.mockResolvedValue(connection);
  });

  it('is disabled by default and sends nothing', async () => {
    settingsRepository.findOne.mockResolvedValue(null);
    await expect(service.runForOrganization('org-1')).resolves.toMatchObject({
      sent: 0,
      skipped: 'disabled',
    });
    expect(meta.sendTemplateMessage).not.toHaveBeenCalled();
  });

  it('creates the Meta template when enabling and does not send until approved', async () => {
    settingsRepository.findOne.mockResolvedValue(null);
    meta.getTemplateStatus.mockResolvedValue(null);
    meta.createUtilityTemplate.mockResolvedValue({ status: 'PENDING' });

    const saved = await service.updateSettings('org-1', { enabled: true });
    expect(meta.createUtilityTemplate).toHaveBeenCalledWith(
      'WABA1',
      expect.objectContaining({ name: 'service_reminder', language: 'ru' }),
      'token',
    );
    expect(saved).toMatchObject({ enabled: true, templateStatus: 'PENDING', connectionId: 'conn-1' });

    settingsRepository.findOne.mockResolvedValue({ ...saved });
    meta.getTemplateStatus.mockResolvedValue({ status: 'PENDING' });
    await expect(service.runForOrganization('org-1')).resolves.toMatchObject({
      skipped: 'template',
    });
    expect(meta.sendTemplateMessage).not.toHaveBeenCalled();
  });

  it('refuses to enable without an active WhatsApp connection', async () => {
    settingsRepository.findOne.mockResolvedValue(null);
    connectionRepository.findOne.mockResolvedValue(null);
    await expect(service.updateSettings('org-1', { enabled: true })).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('does not run outside business hours', async () => {
    // 01:00 по Алматы
    await service.tick(new Date('2026-10-13T20:00:00Z'));
    expect(settingsRepository.find).not.toHaveBeenCalled();
  });
});
