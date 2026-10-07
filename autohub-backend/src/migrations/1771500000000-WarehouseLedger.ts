import { MigrationInterface, QueryRunner } from 'typeorm';

export class WarehouseLedger1771500000000 implements MigrationInterface {
  name = 'WarehouseLedger1771500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "items"
        ADD COLUMN "reservedQuantity" integer NOT NULL DEFAULT 0,
        ADD COLUMN "locationId" uuid,
        ADD CONSTRAINT "CHK_items_reserved" CHECK (
          "reservedQuantity" >= 0
          AND ("quantity" < 0 OR "reservedQuantity" <= "quantity")
        )
    `);

    await queryRunner.query(`
      CREATE TABLE "warehouse_locations" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organizationId" uuid NOT NULL,
        "warehouseId" uuid NOT NULL,
        "parentId" uuid,
        "kind" character varying(10) NOT NULL,
        "code" character varying(100) NOT NULL,
        "barcode" character varying(100),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_warehouse_locations" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_warehouse_locations_kind" CHECK ("kind" IN ('zone', 'rack', 'cell')),
        CONSTRAINT "FK_warehouse_locations_warehouse" FOREIGN KEY ("warehouseId")
          REFERENCES "warehouses"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_warehouse_locations_parent" FOREIGN KEY ("parentId")
          REFERENCES "warehouse_locations"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_warehouse_locations_code"
      ON "warehouse_locations" ("warehouseId", "code")
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_warehouse_locations_barcode"
      ON "warehouse_locations" ("organizationId", "barcode")
      WHERE "barcode" IS NOT NULL
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_warehouse_locations_parent"
      ON "warehouse_locations" ("parentId")
    `);

    await queryRunner.query(`
      INSERT INTO "warehouse_locations" ("organizationId", "warehouseId", "kind", "code")
      SELECT i."organizationId", i."warehouseId", 'cell', i."warehouseCell"
      FROM "items" i
      WHERE i."warehouseId" IS NOT NULL
        AND i."warehouseCell" IS NOT NULL
        AND btrim(i."warehouseCell") <> ''
      GROUP BY i."organizationId", i."warehouseId", i."warehouseCell"
    `);
    await queryRunner.query(`
      UPDATE "items" i
      SET "locationId" = l.id
      FROM "warehouse_locations" l
      WHERE l."organizationId" = i."organizationId"
        AND l."warehouseId" = i."warehouseId"
        AND l.code = i."warehouseCell"
    `);
    await queryRunner.query(`
      ALTER TABLE "items"
        ADD CONSTRAINT "FK_items_location" FOREIGN KEY ("locationId")
        REFERENCES "warehouse_locations"("id") ON DELETE SET NULL
    `);

    await queryRunner.query(`
      CREATE TABLE "inventory_movements" (
        "id" BIGSERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "type" character varying(30) NOT NULL,
        "quantityDelta" integer NOT NULL,
        "quantityAfter" integer NOT NULL,
        "reservedDelta" integer NOT NULL DEFAULT 0,
        "reservedAfter" integer NOT NULL,
        "warehouseId" uuid,
        "locationId" uuid,
        "documentType" character varying(40),
        "documentId" character varying(64),
        "reason" character varying(200),
        "userId" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_movements" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_inventory_movements_type" CHECK ("type" IN (
          'receiving', 'transfer', 'sale', 'reservation', 'reservation_release',
          'return', 'write_off', 'inventory_adjustment'
        )),
        CONSTRAINT "FK_inventory_movements_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_inventory_movements_item"
      ON "inventory_movements" ("organizationId", "itemId", "createdAt")
    `);

    await queryRunner.query(`
      CREATE TABLE "write_offs" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organizationId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "quantity" integer NOT NULL,
        "reason" character varying(20) NOT NULL,
        "note" character varying(500),
        "userId" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_write_offs" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_write_offs_quantity" CHECK ("quantity" > 0),
        CONSTRAINT "CHK_write_offs_reason" CHECK ("reason" IN ('damaged', 'lost', 'defect', 'other')),
        CONSTRAINT "FK_write_offs_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_write_offs_org_created"
      ON "write_offs" ("organizationId", "createdAt")
    `);

    await queryRunner.query(`
      CREATE TABLE "stocktakings" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organizationId" uuid NOT NULL,
        "warehouseId" uuid NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'draft',
        "createdByUserId" uuid,
        "approvedByUserId" uuid,
        "approvedAt" TIMESTAMP,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_stocktakings" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_stocktakings_status" CHECK ("status" IN ('draft', 'approved', 'cancelled')),
        CONSTRAINT "FK_stocktakings_warehouse" FOREIGN KEY ("warehouseId")
          REFERENCES "warehouses"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_stocktakings_org_status"
      ON "stocktakings" ("organizationId", "status")
    `);
    await queryRunner.query(`
      CREATE TABLE "stocktaking_lines" (
        "id" SERIAL NOT NULL,
        "stocktakingId" uuid NOT NULL,
        "itemId" integer NOT NULL,
        "expectedQuantity" integer NOT NULL,
        "countedQuantity" integer,
        CONSTRAINT "PK_stocktaking_lines" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_stocktaking_lines_counted" CHECK ("countedQuantity" IS NULL OR "countedQuantity" >= 0),
        CONSTRAINT "FK_stocktaking_lines_doc" FOREIGN KEY ("stocktakingId")
          REFERENCES "stocktakings"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_stocktaking_lines_item" FOREIGN KEY ("itemId")
          REFERENCES "items"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_stocktaking_lines_item"
      ON "stocktaking_lines" ("stocktakingId", "itemId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "stocktaking_lines"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "stocktakings"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "write_offs"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "inventory_movements"`);
    await queryRunner.query(`
      ALTER TABLE "items" DROP CONSTRAINT IF EXISTS "FK_items_location"
    `);
    await queryRunner.query(`DROP TABLE IF EXISTS "warehouse_locations"`);
    await queryRunner.query(`
      ALTER TABLE "items"
        DROP CONSTRAINT IF EXISTS "CHK_items_reserved",
        DROP COLUMN IF EXISTS "locationId",
        DROP COLUMN IF EXISTS "reservedQuantity"
    `);
  }
}
