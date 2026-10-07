import { MigrationInterface, QueryRunner } from 'typeorm';

export class SalesLedger1771600000000 implements MigrationInterface {
  name = 'SalesLedger1771600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
        ADD COLUMN "stockHold" character varying(10) NOT NULL DEFAULT 'sale'
    `);
    await queryRunner.query(`
      UPDATE "orders" SET "stockHold" = 'none' WHERE "isB2C" = true
    `);

    await queryRunner.query(`
      CREATE TABLE "order_number_counters" (
        "organizationId" uuid NOT NULL,
        "year" integer NOT NULL,
        "lastValue" integer NOT NULL,
        CONSTRAINT "PK_order_number_counters" PRIMARY KEY ("organizationId", "year")
      )
    `);
    await queryRunner.query(`
      INSERT INTO "order_number_counters" ("organizationId", "year", "lastValue")
      SELECT "organizationId",
        CAST(substring("orderNumber" from 'ORD-(\\d{4})-') AS integer),
        MAX(CAST(substring("orderNumber" from 'ORD-\\d{4}-(\\d+)') AS integer))
      FROM "orders"
      WHERE "orderNumber" ~ '^ORD-\\d{4}-\\d+$'
      GROUP BY "organizationId", CAST(substring("orderNumber" from 'ORD-(\\d{4})-') AS integer)
    `);

    await queryRunner.query(`
      ALTER TABLE "order_payments"
        ADD COLUMN "kind" character varying(10) NOT NULL DEFAULT 'payment',
        ADD COLUMN "idempotencyKey" character varying(80)
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_order_payments_idempotency"
      ON "order_payments" ("organizationId", "idempotencyKey")
      WHERE "idempotencyKey" IS NOT NULL
    `);

    await queryRunner.query(`
      CREATE TABLE "reservations" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organizationId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "quantity" integer NOT NULL,
        "status" character varying(30) NOT NULL DEFAULT 'active',
        "orderId" integer,
        "expiresAt" TIMESTAMP WITH TIME ZONE,
        "userId" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_reservations" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_reservations_qty" CHECK ("quantity" > 0),
        CONSTRAINT "CHK_reservations_status" CHECK (
          "status" IN ('active', 'expired', 'cancelled', 'converted_to_order')
        ),
        CONSTRAINT "FK_reservations_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_reservations_due"
      ON "reservations" ("organizationId", "status", "expiresAt")
    `);

    await queryRunner.query(`
      CREATE TABLE "sale_returns" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organizationId" uuid NOT NULL,
        "orderId" integer NOT NULL,
        "itemId" integer NOT NULL,
        "quantity" integer NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'requested',
        "refundAmount" numeric(10,2),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_sale_returns" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_sale_returns_qty" CHECK ("quantity" > 0),
        CONSTRAINT "CHK_sale_returns_status" CHECK (
          "status" IN ('requested', 'inspection', 'restocked', 'written_off')
        ),
        CONSTRAINT "FK_sale_returns_order" FOREIGN KEY ("orderId")
          REFERENCES "orders"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_sale_returns_order"
      ON "sale_returns" ("organizationId", "orderId")
    `);

    await queryRunner.query(`
      ALTER TABLE "customers"
        ADD COLUMN "whatsappPhone" character varying(20),
        ADD COLUMN "companyName" character varying(200)
    `);
    await queryRunner.query(`
      UPDATE "customers"
      SET phone = NULL
      WHERE phone IS NOT NULL AND btrim(phone) = ''
    `);
    await queryRunner.query(`
      UPDATE "customers"
      SET phone = '+' || CASE
        WHEN regexp_replace(phone, '\\D', '', 'g') ~ '^8\\d{10}$'
          THEN '7' || substring(regexp_replace(phone, '\\D', '', 'g') from 2)
        WHEN regexp_replace(phone, '\\D', '', 'g') ~ '^\\d{11,15}$'
          THEN regexp_replace(phone, '\\D', '', 'g')
        ELSE regexp_replace(phone, '\\D', '', 'g')
      END
      WHERE phone IS NOT NULL
        AND phone NOT LIKE '+%'
        AND regexp_replace(phone, '\\D', '', 'g') <> ''
    `);
    await queryRunner.query(`
      UPDATE "customers" AS later
      SET phone = NULL
      WHERE later.phone IS NOT NULL
        AND later.id <> (
          SELECT MIN(first.id)
          FROM "customers" first
          WHERE first.phone = later.phone
            AND first."organizationId" = later."organizationId"
        )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_customers_org_phone"
      ON "customers" ("organizationId", phone)
      WHERE phone IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_customers_org_phone"`);
    await queryRunner.query(`
      ALTER TABLE "customers"
        DROP COLUMN IF EXISTS "companyName",
        DROP COLUMN IF EXISTS "whatsappPhone"
    `);
    await queryRunner.query(`DROP TABLE IF EXISTS "sale_returns"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "reservations"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_order_payments_idempotency"`);
    await queryRunner.query(`
      ALTER TABLE "order_payments"
        DROP COLUMN IF EXISTS "idempotencyKey",
        DROP COLUMN IF EXISTS "kind"
    `);
    await queryRunner.query(`DROP TABLE IF EXISTS "order_number_counters"`);
    await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "stockHold"`);
  }
}
