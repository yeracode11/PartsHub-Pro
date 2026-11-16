import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import {
  PhoneVerificationService,
  extractCodes,
} from './phone-verification.service';
import { PhoneVerification } from './entities/phone-verification.entity';

/** Простая in-memory замена репозитория: поддерживает только нужные запросы. */
function createRepo() {
  const rows: PhoneVerification[] = [];
  const matches = (row: any, where: any) =>
    Object.entries(where ?? {}).every(([key, cond]: [string, any]) => {
      if (cond && typeof cond === 'object' && '_type' in cond) {
        if (cond._type === 'moreThan') return row[key] > cond._value;
        throw new Error(`unsupported operator ${cond._type}`);
      }
      return row[key] === cond;
    });
  return {
    rows,
    create: (data: Partial<PhoneVerification>) => ({ ...data }) as PhoneVerification,
    save: jest.fn(async (row: PhoneVerification) => {
      if (!row.id) {
        row.id = `00000000-0000-4000-8000-${String(rows.length + 1).padStart(12, '0')}`;
        row.createdAt = new Date();
        rows.push(row);
      }
      return row;
    }),
    count: jest.fn(async ({ where }) => rows.filter((r) => matches(r, where)).length),
    findOne: jest.fn(async ({ where }) => rows.find((r) => matches(r, where)) ?? null),
    update: jest.fn(async (where, patch) => {
      const hit = rows.filter((r) => matches(r, where));
      hit.forEach((r) => Object.assign(r, patch));
      return { affected: hit.length };
    }),
  };
}

describe('PhoneVerificationService', () => {
  let repo: ReturnType<typeof createRepo>;
  let service: PhoneVerificationService;
  const env: Record<string, string> = {};

  beforeEach(() => {
    repo = createRepo();
    env.WHATSAPP_VERIFY_BOT_PHONE = '+7 700 000 00 01';
    env.PHONE_VERIFICATION_REQUIRED = '';
    const config = { get: (key: string) => env[key] } as unknown as ConfigService;
    service = new PhoneVerificationService(
      repo as any,
      new JwtService({ secret: 'test-secret' }),
      config,
    );
  });

  it('extracts standalone 6-digit codes', () => {
    expect(extractCodes('Код Vinly: 042315')).toEqual(['042315']);
    expect(extractCodes('код 042 315')).toEqual(['042315']);
    expect(extractCodes('артикул 1234567')).toEqual([]);
  });

  it('starts a verification with a wa.me link to the bot', async () => {
    const started = await service.start('87771234567', 'register');

    expect(started.code).toMatch(/^\d{6}$/);
    expect(started.botPhone).toBe('77000000001');
    expect(started.waLink).toBe(
      `https://wa.me/77000000001?text=${encodeURIComponent(`Код Vinly: ${started.code}`)}`,
    );
    expect(repo.rows[0].phone).toBe('+77771234567');
    expect(repo.rows[0].secretHash).not.toBe(started.secret);
  });

  it('refuses to start when the bot phone is not configured', async () => {
    env.WHATSAPP_VERIFY_BOT_PHONE = '';
    await expect(service.start('+77771234567', 'login')).rejects.toThrow(
      'временно недоступно',
    );
  });

  it('verifies when the code comes from the same number and issues a one-time token', async () => {
    const started = await service.start('+77771234567', 'register');

    const pending = await service.getStatus(started.verificationId, started.secret);
    expect(pending).toEqual({ status: 'pending' });

    const reply = await service.handleInboundMessage({
      from: '77771234567',
      text: started.message,
      messageId: 'wamid.1',
    });
    expect(reply).toContain('подтверждён');

    const status = await service.getStatus(started.verificationId, started.secret);
    expect(status.status).toBe('verified');
    expect(status.phone).toBe('+77771234567');

    const claims = await service.consumeToken(status.verificationToken!, ['register']);
    expect(claims.phone).toBe('+77771234567');

    await expect(
      service.consumeToken(status.verificationToken!, ['register']),
    ).rejects.toThrow('уже использовано');
  });

  it('does not verify when the code is sent from another number', async () => {
    const started = await service.start('+77771234567', 'login');

    const reply = await service.handleInboundMessage({
      from: '77019998877',
      text: started.code,
      messageId: 'wamid.2',
    });

    expect(reply).toContain('не совпадает');
    const status = await service.getStatus(started.verificationId, started.secret);
    expect(status.status).toBe('pending');
  });

  it('rejects a status poll with a wrong secret', async () => {
    const started = await service.start('+77771234567', 'login');
    await expect(
      service.getStatus(started.verificationId, 'nope'),
    ).rejects.toThrow('не найден');
  });

  it('ignores ordinary bot messages without a matching code', async () => {
    await service.start('+77771234567', 'login');
    const reply = await service.handleInboundMessage({
      from: '77771234567',
      text: 'камри 70 колодки 123456',
      messageId: 'wamid.3',
    });
    expect(reply).toBeNull();
  });

  it('rejects a token issued for another purpose', async () => {
    const started = await service.start('+77771234567', 'login');
    await service.handleInboundMessage({
      from: '77771234567',
      text: started.code,
      messageId: 'wamid.4',
    });
    const status = await service.getStatus(started.verificationId, started.secret);
    await expect(
      service.consumeToken(status.verificationToken!, ['register']),
    ).rejects.toThrow('Неверный токен');
  });
});
