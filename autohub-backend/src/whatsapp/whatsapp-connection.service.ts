import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  WhatsAppConnection,
  WhatsAppConnectionStatus,
} from './entities/whatsapp-connection.entity';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

export type WhatsAppConnectionPublic = Omit<
  WhatsAppConnection,
  'accessToken'
>;

@Injectable()
export class WhatsAppConnectionService {
  private readonly logger = new Logger(WhatsAppConnectionService.name);

  constructor(
    @InjectRepository(WhatsAppConnection)
    private readonly repo: Repository<WhatsAppConnection>,
    private readonly metaConfig: MetaWhatsAppConfig,
  ) {}

  /** Никогда не включает accessToken в возвращаемый объект. */
  toPublic(connection: WhatsAppConnection): WhatsAppConnectionPublic {
    const { accessToken: _token, ...rest } = connection;
    return rest;
  }

  async findByPhoneNumberId(
    phoneNumberId: string,
  ): Promise<WhatsAppConnection | null> {
    return this.repo.findOne({
      where: {
        phoneNumberId,
        status: WhatsAppConnectionStatus.ACTIVE,
      },
    });
  }

  async findAllByOrganization(
    organizationId: string,
  ): Promise<WhatsAppConnectionPublic[]> {
    const rows = await this.repo.find({
      where: { organizationId },
      order: { createdAt: 'DESC' },
    });
    return rows.map((r) => this.toPublic(r));
  }

  /**
   * organizationId приходит от вызывающего контроллера строго из JWT.
   *
   * accessToken: приоритет —
   *   1) явно переданный (server-side/admin use; Flutter его не передаёт);
   *   2) META_WHATSAPP_ACCESS_TOKEN из env (MetaWhatsAppConfig.fallbackAccessToken).
   * Если ни того, ни другого нет — подключение не создаётся (без "тихого" успеха).
   */
  async createForOrganization(
    organizationId: string,
    data: {
      phoneNumberId: string;
      accessToken?: string;
      wabaId?: string;
      phoneNumber?: string;
      displayName?: string;
    },
  ): Promise<WhatsAppConnectionPublic> {
    const explicitToken = data.accessToken?.trim();
    const envToken = this.metaConfig.fallbackAccessToken?.trim();
    const resolvedAccessToken = explicitToken || envToken;

    if (!resolvedAccessToken) {
      this.logger.error(
        `META connection create blocked: access token not configured organizationId=${organizationId} phoneNumberId=${data.phoneNumberId}`,
      );
      throw new HttpException(
        'Meta WhatsApp access token is not configured on server',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    const entity = this.repo.create({
      organizationId,
      phoneNumberId: data.phoneNumberId,
      accessToken: resolvedAccessToken,
      wabaId: data.wabaId ?? null,
      phoneNumber: data.phoneNumber ?? null,
      displayName: data.displayName ?? null,
      status: WhatsAppConnectionStatus.ACTIVE,
    });

    try {
      const saved = await this.repo.save(entity);
      this.logger.log(
        `META connection create organizationId=${organizationId} phoneNumberId=${saved.phoneNumberId} wabaId=${saved.wabaId ?? 'n/a'} status=${saved.status}`,
      );
      return this.toPublic(saved);
    } catch (error: unknown) {
      const code =
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: string }).code;
      if (code === '23505') {
        throw new ConflictException(
          'Этот Phone Number ID уже подключён к другой организации',
        );
      }
      throw error;
    }
  }

  async getByIdForOrganization(
    id: string,
    organizationId: string,
  ): Promise<WhatsAppConnection> {
    const row = await this.repo.findOne({ where: { id, organizationId } });
    if (!row) {
      throw new NotFoundException('WhatsApp connection not found');
    }
    return row;
  }
}
