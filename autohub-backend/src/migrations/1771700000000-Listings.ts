import { MigrationInterface, QueryRunner } from 'typeorm';

export class Listings1771700000000 implements MigrationInterface {
  name = 'Listings1771700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "listings" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organizationId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "channel" character varying(20) NOT NULL,
        "title" character varying(200) NOT NULL,
        "description" text,
        "photos" jsonb NOT NULL DEFAULT '[]',
        "price" numeric(12,2) NOT NULL,
        "quantity" integer NOT NULL DEFAULT 0,
        "status" character varying(20) NOT NULL DEFAULT 'draft',
        "externalId" character varying(80),
        "publishedAt" TIMESTAMP WITH TIME ZONE,
        "nextAttemptAt" TIMESTAMP WITH TIME ZONE,
        "lastSyncError" character varying(300),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_listings" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_listings_channel" CHECK (
          "channel" IN ('catalog', 'kolesa', 'olx', 'whatsapp', 'telegram')
        ),
        CONSTRAINT "CHK_listings_status" CHECK (
          "status" IN ('draft', 'published', 'paused', 'needs_sync', 'archived')
        ),
        CONSTRAINT "FK_listings_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_listings_item_channel"
      ON "listings" ("organizationId", "itemId", "channel")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_listings_sync"
      ON "listings" ("organizationId", "status", "nextAttemptAt")
    `);
    await queryRunner.query(`
      INSERT INTO "listings" (
        "organizationId", "itemId", "channel", "title", "description", "photos",
        "price", "quantity", "status", "externalId", "publishedAt"
      )
      SELECT
        i."organizationId",
        i.id,
        'catalog',
        left(i.name, 200),
        i.description,
        COALESCE(i.images, '[]'::jsonb),
        i.price,
        GREATEST(i.quantity - i."reservedQuantity", 0),
        'published',
        'catalog:' || i.id::text,
        now()
      FROM "items" i
      WHERE i."syncedToB2C" = true
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "listings"`);
  }
}
