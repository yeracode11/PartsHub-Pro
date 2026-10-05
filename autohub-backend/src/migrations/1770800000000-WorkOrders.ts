import { MigrationInterface, QueryRunner } from 'typeorm';

export class WorkOrders1770800000000 implements MigrationInterface {
  name = 'WorkOrders1770800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "work_catalog" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "name" varchar(255) NOT NULL,
        "normHours" numeric(6,2) NOT NULL DEFAULT 1,
        "pricePerHour" numeric(10,2) NOT NULL DEFAULT 0,
        "isActive" boolean NOT NULL DEFAULT true,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_work_catalog" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_work_catalog_org_name"
      ON "work_catalog" ("organizationId", "name")
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_works" (
        "id" SERIAL NOT NULL,
        "orderId" integer NOT NULL,
        "workCatalogId" integer,
        "name" varchar(255) NOT NULL,
        "normHours" numeric(6,2) NOT NULL DEFAULT 1,
        "pricePerHour" numeric(10,2) NOT NULL DEFAULT 0,
        "subtotal" numeric(10,2) NOT NULL DEFAULT 0,
        "performerId" uuid,
        "done" boolean NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_works" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_works_order" FOREIGN KEY ("orderId")
          REFERENCES "orders"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_order_works_catalog" FOREIGN KEY ("workCatalogId")
          REFERENCES "work_catalog"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_order_works_performer" FOREIGN KEY ("performerId")
          REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_order_works_order" ON "order_works" ("orderId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "order_works"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "work_catalog"`);
  }
}
