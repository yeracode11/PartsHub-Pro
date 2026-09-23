import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  WhatsAppConnection,
  WhatsAppConnectionStatus,
} from './entities/whatsapp-connection.entity';

export type WhatsAppConnectionPublic = Omit<
  WhatsAppConnection,
  'accessToken'
>;

@Injectable()
export class WhatsAppConnectionService {
  constructor(
    @InjectRepository(WhatsAppConnection)
    private readonly repo: Repository<WhatsAppConnection>,
  ) {}

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

  async createForOrganization(
    organizationId: string,
    data: {
      phoneNumberId: string;
      accessToken: string;
      wabaId?: string;
      phoneNumber?: string;
      displayName?: string;
    },
  ): Promise<WhatsAppConnectionPublic> {
    const entity = this.repo.create({
      organizationId,
      phoneNumberId: data.phoneNumberId,
      accessToken: data.accessToken,
      wabaId: data.wabaId ?? null,
      phoneNumber: data.phoneNumber ?? null,
      displayName: data.displayName ?? null,
      status: WhatsAppConnectionStatus.ACTIVE,
    });
    const saved = await this.repo.save(entity);
    return this.toPublic(saved);
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
