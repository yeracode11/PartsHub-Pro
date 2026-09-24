import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';

/**
 * Кэш соответствия wa_id → Graph API `input`, полученный из успешных ответов Meta
 * (contacts[].wa_id + contacts[].input). Не хардкод префиксов — только то, что вернул Meta.
 */
@Entity('whatsapp_meta_recipient_cache')
export class WhatsAppMetaRecipientCache {
  @PrimaryColumn({ type: 'varchar', length: 32 })
  waId: string;

  @Column({ type: 'varchar', length: 32 })
  graphApiInput: string;

  @UpdateDateColumn()
  updatedAt: Date;
}
