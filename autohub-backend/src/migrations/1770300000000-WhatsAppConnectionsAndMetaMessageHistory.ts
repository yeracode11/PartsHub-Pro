import { MigrationInterface, QueryRunner } from 'typeorm';

export class WhatsAppConnectionsAndMetaMessageHistory1770300000000
  implements MigrationInterface
{
  name = 'WhatsAppConnectionsAndMetaMessageHistory1770300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "whatsapp_connections" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "organizationId" uuid NOT NULL,
        "phoneNumberId" character varying(32) NOT NULL,
        "wabaId" character varying(64),
        "phoneNumber" character varying(32),
        "displayName" character varying(255),
        "accessToken" text NOT NULL,
        "status" character varying(32) NOT NULL DEFAULT 'active',
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_whatsapp_connections" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_whatsapp_connections_phone_number_id" UNIQUE ("phoneNumberId"),
        CONSTRAINT "FK_whatsapp_connections_organization" FOREIGN KEY ("organizationId")
          REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_whatsapp_connections_organizationId"
      ON "whatsapp_connections" ("organizationId")
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_whatsapp_connections_wabaId"
      ON "whatsapp_connections" ("wabaId")
    `);

    await queryRunner.query(`
      CREATE TYPE "public"."message_history_direction_enum" AS ENUM('inbound', 'outbound')
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ALTER COLUMN "sentBy" DROP NOT NULL
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ADD COLUMN "whatsappConnectionId" uuid
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ADD COLUMN "direction" "public"."message_history_direction_enum"
      NOT NULL DEFAULT 'outbound'
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ADD COLUMN "externalMessageId" character varying(255)
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ADD COLUMN "messageType" character varying(50)
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ADD COLUMN "metadata" jsonb
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_message_history_external_message_id"
      ON "message_history" ("externalMessageId")
      WHERE "externalMessageId" IS NOT NULL
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_message_history_organization_phone"
      ON "message_history" ("organizationId", "phone")
    `);

    await queryRunner.query(`
      ALTER TABLE "message_history"
      ADD CONSTRAINT "FK_message_history_whatsapp_connection"
      FOREIGN KEY ("whatsappConnectionId") REFERENCES "whatsapp_connections"("id")
      ON DELETE SET NULL ON UPDATE NO ACTION
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "message_history" DROP CONSTRAINT "FK_message_history_whatsapp_connection"
    `);
    await queryRunner.query(`DROP INDEX "IDX_message_history_organization_phone"`);
    await queryRunner.query(`DROP INDEX "UQ_message_history_external_message_id"`);
    await queryRunner.query(`ALTER TABLE "message_history" DROP COLUMN "metadata"`);
    await queryRunner.query(`ALTER TABLE "message_history" DROP COLUMN "messageType"`);
    await queryRunner.query(`ALTER TABLE "message_history" DROP COLUMN "externalMessageId"`);
    await queryRunner.query(`ALTER TABLE "message_history" DROP COLUMN "direction"`);
    await queryRunner.query(`ALTER TABLE "message_history" DROP COLUMN "whatsappConnectionId"`);
    await queryRunner.query(`
      ALTER TABLE "message_history" ALTER COLUMN "sentBy" SET NOT NULL
    `);
    await queryRunner.query(`DROP TYPE "public"."message_history_direction_enum"`);
    await queryRunner.query(`DROP INDEX "IDX_whatsapp_connections_wabaId"`);
    await queryRunner.query(`DROP INDEX "IDX_whatsapp_connections_organizationId"`);
    await queryRunner.query(`DROP TABLE "whatsapp_connections"`);
  }
}
