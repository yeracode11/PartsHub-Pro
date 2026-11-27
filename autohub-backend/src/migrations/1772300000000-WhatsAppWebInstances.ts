import { MigrationInterface, QueryRunner } from 'typeorm';

export class WhatsAppWebInstances1772300000000 implements MigrationInterface {
  name = 'WhatsAppWebInstances1772300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "whatsapp_web_instances" (
        "organizationId" uuid NOT NULL,
        "state" character varying(32) NOT NULL DEFAULT 'stopped',
        "phone" character varying(20),
        "reason" character varying(64),
        "botEnabled" boolean NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_whatsapp_web_instances" PRIMARY KEY ("organizationId"),
        CONSTRAINT "FK_whatsapp_web_instances_org" FOREIGN KEY ("organizationId")
          REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
    // Чаты QR-канала выбираются по metadata.channel и телефону.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_message_history_org_channel_phone"
      ON "message_history" ("organizationId", ((metadata->>'channel')), "phone", "sentAt" DESC)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_message_history_org_channel_phone"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "whatsapp_web_instances"`);
  }
}
