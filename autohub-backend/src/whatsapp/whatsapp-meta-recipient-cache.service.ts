import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { WhatsAppMetaRecipientCache } from './entities/whatsapp-meta-recipient-cache.entity';
import { toMetaWhatsAppDigits } from './meta-whatsapp-recipient.util';

@Injectable()
export class WhatsAppMetaRecipientCacheService {
  constructor(
    @InjectRepository(WhatsAppMetaRecipientCache)
    private readonly repo: Repository<WhatsAppMetaRecipientCache>,
  ) {}

  async resolveGraphApiTo(waId: string): Promise<string | null> {
    const key = toMetaWhatsAppDigits(waId);
    const row = await this.repo.findOne({ where: { waId: key } });
    return row?.graphApiInput ?? null;
  }

  async rememberFromMetaResponse(
    waId: string | undefined,
    graphApiInput: string | undefined,
  ): Promise<void> {
    if (!waId?.trim() || !graphApiInput?.trim()) {
      return;
    }

    const key = toMetaWhatsAppDigits(waId);
    const input = toMetaWhatsAppDigits(graphApiInput);

    await this.repo.save(
      this.repo.create({
        waId: key,
        graphApiInput: input,
      }),
    );
  }
}
