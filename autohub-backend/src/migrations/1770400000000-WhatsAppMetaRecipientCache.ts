import { MigrationInterface, QueryRunner } from 'typeorm';

export class WhatsAppMetaRecipientCache1770400000000
  implements MigrationInterface
{
  name = 'WhatsAppMetaRecipientCache1770400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "whatsapp_meta_recipient_cache" (
        "waId" character varying(32) NOT NULL,
        "graphApiInput" character varying(32) NOT NULL,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_whatsapp_meta_recipient_cache" PRIMARY KEY ("waId")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "whatsapp_meta_recipient_cache"`);
  }
}
