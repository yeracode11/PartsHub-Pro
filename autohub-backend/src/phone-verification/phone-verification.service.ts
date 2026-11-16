import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'crypto';
import { MoreThan, Repository } from 'typeorm';
import {
  normalizePhoneE164,
  phoneDigitsKey,
} from '../common/utils/phone.util';
import {
  PhoneVerification,
  PhoneVerificationPurpose,
} from './entities/phone-verification.entity';

/** Сколько живёт код в ожидании сообщения от пользователя. */
export const VERIFICATION_TTL_MS = 10 * 60 * 1000;
/** Сколько живёт токен подтверждённого номера (на регистрацию/вход). */
const VERIFIED_TOKEN_TTL = '15m';
/** Не больше N запросов кода на номер за окно. */
const MAX_STARTS_PER_WINDOW = 5;
const START_WINDOW_MS = 10 * 60 * 1000;
/** После стольких сообщений с чужого номера код сгорает. */
const MAX_MISMATCHES = 5;

const TOKEN_KIND = 'phone_verification';

export interface StartedVerification {
  verificationId: string;
  secret: string;
  code: string;
  /** Номер бота в формате цифр (для wa.me). */
  botPhone: string;
  /** Текст, который приложение подставит в WhatsApp. */
  message: string;
  /** Готовая ссылка: открывает чат с ботом и заполненным текстом. */
  waLink: string;
  expiresAt: string;
}

export interface VerificationStatus {
  status: 'pending' | 'verified' | 'consumed' | 'expired';
  phone?: string;
  verificationToken?: string;
}

export interface VerifiedPhoneClaims {
  phone: string;
  purpose: PhoneVerificationPurpose;
  verificationId: string;
}

@Injectable()
export class PhoneVerificationService {
  private readonly logger = new Logger(PhoneVerificationService.name);

  constructor(
    @InjectRepository(PhoneVerification)
    private readonly repo: Repository<PhoneVerification>,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {}

  /** Номер бота Vinly для верификации (цифры без +). Пусто — функция выключена. */
  get botPhone(): string {
    const raw = this.config.get<string>('WHATSAPP_VERIFY_BOT_PHONE') ?? '';
    return raw.replace(/\D/g, '');
  }

  /** Если true — регистрация без подтверждённого номера запрещена. */
  get isRequiredForRegistration(): boolean {
    return (
      (this.config.get<string>('PHONE_VERIFICATION_REQUIRED') ?? '')
        .trim()
        .toLowerCase() === 'true'
    );
  }

  async start(
    rawPhone: string,
    purpose: PhoneVerificationPurpose,
  ): Promise<StartedVerification> {
    const botPhone = this.botPhone;
    if (!botPhone) {
      throw new ServiceUnavailableException(
        'Подтверждение через WhatsApp временно недоступно',
      );
    }

    const phone = normalizePhoneE164(rawPhone);

    const recent = await this.repo.count({
      where: {
        phone,
        createdAt: MoreThan(new Date(Date.now() - START_WINDOW_MS)),
      },
    });
    if (recent >= MAX_STARTS_PER_WINDOW) {
      throw new HttpException(
        'Слишком много попыток. Попробуйте через 10 минут',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = await this.generateUniqueCode();
    const secret = randomBytes(24).toString('hex');
    const expiresAt = new Date(Date.now() + VERIFICATION_TTL_MS);

    const saved = await this.repo.save(
      this.repo.create({
        phone,
        code,
        secretHash: sha256(secret),
        purpose,
        status: 'pending',
        mismatchCount: 0,
        inboundMessageId: null,
        expiresAt,
        verifiedAt: null,
      }),
    );

    const message = `Код Vinly: ${code}`;
    return {
      verificationId: saved.id,
      secret,
      code,
      botPhone,
      message,
      waLink: `https://wa.me/${botPhone}?text=${encodeURIComponent(message)}`,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** Опрос статуса приложением. Токен выдаётся, только когда номер подтверждён. */
  async getStatus(
    verificationId: string,
    secret: string,
  ): Promise<VerificationStatus> {
    const row = await this.repo.findOne({ where: { id: verificationId } });
    if (!row || !secretMatches(secret, row.secretHash)) {
      throw new UnauthorizedException('Запрос подтверждения не найден');
    }

    if (row.status === 'pending' && row.expiresAt.getTime() <= Date.now()) {
      row.status = 'expired';
      await this.repo.save(row);
    }

    if (row.status !== 'verified') {
      return { status: row.status };
    }

    const verificationToken = this.jwtService.sign(
      {
        kind: TOKEN_KIND,
        phone: row.phone,
        purpose: row.purpose,
        vid: row.id,
      },
      { expiresIn: VERIFIED_TOKEN_TTL },
    );
    return { status: 'verified', phone: row.phone, verificationToken };
  }

  /**
   * Входящее сообщение WhatsApp. Возвращает текст ответа, если сообщение
   * относится к верификации, иначе null (сообщение уходит обычному боту).
   */
  async handleInboundMessage(input: {
    from: string;
    text: string;
    messageId: string;
  }): Promise<string | null> {
    const text = input.text ?? '';
    const candidates = extractCodes(text);
    const mentionsVinly = /vinly|винли/i.test(text);
    if (candidates.length === 0) {
      return mentionsVinly && /код|code/i.test(text)
        ? 'Не нашли код в сообщении. Вернитесь в приложение и нажмите «Открыть WhatsApp» ещё раз.'
        : null;
    }

    const now = new Date();
    let row: PhoneVerification | null = null;
    for (const code of candidates) {
      row = await this.repo.findOne({
        where: { code, status: 'pending', expiresAt: MoreThan(now) },
        order: { createdAt: 'DESC' },
      });
      if (row) break;
    }

    if (!row) {
      if (!mentionsVinly) return null;
      const already = await this.repo.findOne({
        where: { inboundMessageId: input.messageId },
      });
      if (already) return null;
      return 'Код не найден или истёк. Запросите новый код в приложении Vinly.';
    }

    if (row.inboundMessageId === input.messageId) {
      return null;
    }

    const senderKey = phoneDigitsKey(input.from);
    if (senderKey !== phoneDigitsKey(row.phone)) {
      row.mismatchCount += 1;
      if (row.mismatchCount >= MAX_MISMATCHES) {
        row.status = 'expired';
      }
      await this.repo.save(row);
      this.logger.warn(
        `WhatsApp verification mismatch id=${row.id} attempts=${row.mismatchCount}`,
      );
      return 'Этот WhatsApp не совпадает с номером, который вы указали в приложении. Отправьте код с того же номера.';
    }

    row.status = 'verified';
    row.verifiedAt = now;
    row.inboundMessageId = input.messageId;
    await this.repo.save(row);
    this.logger.log(`WhatsApp verification confirmed id=${row.id}`);
    return '✅ Номер подтверждён. Вернитесь в приложение Vinly.';
  }

  /**
   * Проверяет токен и гасит его (одноразовый). Возвращает подтверждённый номер.
   */
  async consumeToken(
    token: string,
    allowedPurposes: PhoneVerificationPurpose[],
  ): Promise<VerifiedPhoneClaims> {
    let payload: { kind?: string; phone?: string; purpose?: string; vid?: string };
    try {
      payload = this.jwtService.verify(token);
    } catch {
      throw new UnauthorizedException(
        'Подтверждение номера истекло. Пройдите его ещё раз',
      );
    }

    if (
      payload.kind !== TOKEN_KIND ||
      !payload.phone ||
      !payload.vid ||
      !allowedPurposes.includes(payload.purpose as PhoneVerificationPurpose)
    ) {
      throw new BadRequestException('Неверный токен подтверждения номера');
    }

    const result = await this.repo.update(
      { id: payload.vid, status: 'verified' },
      { status: 'consumed' },
    );
    if (!result.affected) {
      throw new UnauthorizedException(
        'Подтверждение номера уже использовано. Пройдите его ещё раз',
      );
    }

    return {
      phone: payload.phone,
      purpose: payload.purpose as PhoneVerificationPurpose,
      verificationId: payload.vid,
    };
  }

  private async generateUniqueCode(): Promise<string> {
    for (let i = 0; i < 10; i++) {
      const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
      const clash = await this.repo.count({
        where: { code, status: 'pending', expiresAt: MoreThan(new Date()) },
      });
      if (clash === 0) return code;
    }
    throw new ServiceUnavailableException('Не удалось создать код, повторите');
  }
}

/** Отдельно стоящие 6-значные числа (пробелы/дефисы внутри допускаются: «123 456»). */
export function extractCodes(text: string): string[] {
  const result: string[] = [];
  const re = /(?<!\d)(\d{3})[\s-]?(\d{3})(?!\d)/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(text)) !== null) {
    result.push(`${match[1]}${match[2]}`);
  }
  return [...new Set(result)].slice(0, 3);
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function secretMatches(secret: string, expectedHash: string): boolean {
  const actual = Buffer.from(sha256(secret ?? ''), 'hex');
  const expected = Buffer.from(expectedHash, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
