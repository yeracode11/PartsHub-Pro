import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Каталог: коды и OEM у товара, закупочная цена, кроссы, применимость
 * и индексы для поиска на десятках тысяч позиций.
 */
export class CatalogFoundation1771400000000 implements MigrationInterface {
  name = 'CatalogFoundation1771400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS pg_trgm`);

    await queryRunner.query(`
      ALTER TABLE "items"
        ADD COLUMN "internalCode" character varying(100),
        ADD COLUMN "barcode" character varying(100),
        ADD COLUMN "oem" character varying(100),
        ADD COLUMN "oemNormalized" character varying(100),
        ADD COLUMN "brand" character varying(100),
        ADD COLUMN "purchaseCost" numeric(12,2),
        ADD COLUMN "status" character varying(20) NOT NULL DEFAULT 'active',
        ADD COLUMN "videos" jsonb,
        ADD CONSTRAINT "CHK_items_status" CHECK ("status" IN ('active', 'archived')),
        ADD CONSTRAINT "CHK_items_purchase_cost" CHECK ("purchaseCost" IS NULL OR "purchaseCost" >= 0)
    `);

    await queryRunner.query(`
      ALTER TABLE "incoming_items"
        ADD COLUMN "salePrice" numeric(10,2),
        ADD COLUMN "oem" character varying(100),
        ADD COLUMN "barcode" character varying(100)
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_items_org_created" ON "items" ("organizationId", "createdAt" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_items_org_sku" ON "items" ("organizationId", "sku")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_items_org_internal_code" ON "items" ("organizationId", "internalCode")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_items_org_oem" ON "items" ("organizationId", "oemNormalized")`,
    );
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_items_org_barcode" ON "items" ("organizationId", "barcode")
      WHERE "barcode" IS NOT NULL
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_items_name_trgm" ON "items" USING gin ("name" gin_trgm_ops)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_items_sku_trgm" ON "items" USING gin ("sku" gin_trgm_ops)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_items_oem_trgm" ON "items" USING gin ("oemNormalized" gin_trgm_ops)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_items_brand_trgm" ON "items" USING gin ("brand" gin_trgm_ops)`,
    );

    await queryRunner.query(`
      CREATE TABLE "part_cross_references" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "oem" character varying(100) NOT NULL,
        "oemNormalized" character varying(100) NOT NULL,
        "brand" character varying(100),
        "type" character varying(20) NOT NULL DEFAULT 'alternative',
        CONSTRAINT "PK_part_cross_references" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_part_cross_references_type" CHECK ("type" IN ('alternative', 'aftermarket')),
        CONSTRAINT "FK_part_cross_references_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_part_cross_references_org_oem" ON "part_cross_references" ("organizationId", "oemNormalized")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_part_cross_references_item_oem" ON "part_cross_references" ("itemId", "oemNormalized")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_part_cross_references_oem_trgm" ON "part_cross_references" USING gin ("oemNormalized" gin_trgm_ops)`,
    );

    await queryRunner.query(`
      CREATE TABLE "part_compatibility" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "make" character varying(50) NOT NULL,
        "model" character varying(80) NOT NULL,
        "generation" character varying(50),
        "yearFrom" smallint,
        "yearTo" smallint,
        "body" character varying(50),
        "engine" character varying(80),
        "transmission" character varying(20),
        CONSTRAINT "PK_part_compatibility" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_part_compatibility_years" CHECK ("yearFrom" IS NULL OR "yearTo" IS NULL OR "yearFrom" <= "yearTo"),
        CONSTRAINT "FK_part_compatibility_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_part_compatibility_org_make_model" ON "part_compatibility" ("organizationId", "make", "model")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_part_compatibility_item" ON "part_compatibility" ("itemId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "part_compatibility"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "part_cross_references"`);
    for (const index of [
      'IDX_items_brand_trgm',
      'IDX_items_oem_trgm',
      'IDX_items_sku_trgm',
      'IDX_items_name_trgm',
      'UQ_items_org_barcode',
      'IDX_items_org_oem',
      'IDX_items_org_internal_code',
      'IDX_items_org_sku',
      'IDX_items_org_created',
    ]) {
      await queryRunner.query(`DROP INDEX IF EXISTS "${index}"`);
    }
    await queryRunner.query(`
      ALTER TABLE "incoming_items"
        DROP COLUMN "barcode",
        DROP COLUMN "oem",
        DROP COLUMN "salePrice"
    `);
    await queryRunner.query(`
      ALTER TABLE "items"
        DROP CONSTRAINT "CHK_items_purchase_cost",
        DROP CONSTRAINT "CHK_items_status",
        DROP COLUMN "videos",
        DROP COLUMN "status",
        DROP COLUMN "purchaseCost",
        DROP COLUMN "brand",
        DROP COLUMN "oemNormalized",
        DROP COLUMN "oem",
        DROP COLUMN "barcode",
        DROP COLUMN "internalCode"
    `);
    // pg_trgm не удаляем: расширением могут пользоваться другие индексы.
  }
}
