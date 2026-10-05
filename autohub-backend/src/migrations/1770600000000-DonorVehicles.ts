import { MigrationInterface, QueryRunner } from 'typeorm';

export class DonorVehicles1770600000000 implements MigrationInterface {
  name = 'DonorVehicles1770600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "public"."donor_vehicles_status_enum"
      AS ENUM ('awaiting', 'dismantling', 'dismantled', 'closed')
    `);
    await queryRunner.query(`
      CREATE TABLE "donor_vehicles" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "brand" character varying(50) NOT NULL,
        "model" character varying(50) NOT NULL,
        "year" integer,
        "vin" character varying(30),
        "engine" character varying(50),
        "color" character varying(50),
        "mileage" integer,
        "purchasePrice" numeric(12,2) NOT NULL DEFAULT 0,
        "extraCosts" numeric(12,2) NOT NULL DEFAULT 0,
        "scrapIncome" numeric(12,2) NOT NULL DEFAULT 0,
        "purchaseDate" date,
        "source" character varying(255),
        "status" "public"."donor_vehicles_status_enum" NOT NULL DEFAULT 'awaiting',
        "notes" text,
        "photos" jsonb,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_donor_vehicles" PRIMARY KEY ("id"),
        CONSTRAINT "FK_donor_vehicles_organization" FOREIGN KEY ("organizationId")
          REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_donor_vehicles_org_status"
      ON "donor_vehicles" ("organizationId", "status")
    `);
    await queryRunner.query(`ALTER TABLE "items" ADD COLUMN "donorId" integer`);
    await queryRunner.query(`
      ALTER TABLE "items" ADD CONSTRAINT "FK_items_donor"
      FOREIGN KEY ("donorId") REFERENCES "donor_vehicles"("id") ON DELETE SET NULL
    `);
    await queryRunner.query(`CREATE INDEX "IDX_items_donorId" ON "items" ("donorId")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_items_donorId"`);
    await queryRunner.query(`ALTER TABLE "items" DROP CONSTRAINT IF EXISTS "FK_items_donor"`);
    await queryRunner.query(`ALTER TABLE "items" DROP COLUMN IF EXISTS "donorId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "donor_vehicles"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "public"."donor_vehicles_status_enum"`);
  }
}
