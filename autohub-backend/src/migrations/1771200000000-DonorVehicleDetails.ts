import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Карточка донора по ТЗ авторазбора: кузов, КПП, привод, статьи расходов, даты разбора
 * и жизненный цикл из шести статусов. Колонка extraCosts остаётся до следующего релиза.
 */
export class DonorVehicleDetails1771200000000 implements MigrationInterface {
  name = 'DonorVehicleDetails1771200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles"
        ADD COLUMN "generation" character varying(50),
        ADD COLUMN "body" character varying(50),
        ADD COLUMN "engineVolume" numeric(3,1),
        ADD COLUMN "transmission" character varying(20),
        ADD COLUMN "drivetrain" character varying(20),
        ADD COLUMN "deliveryCost" numeric(12,2) NOT NULL DEFAULT 0,
        ADD COLUMN "dismantlingCost" numeric(12,2) NOT NULL DEFAULT 0,
        ADD COLUMN "otherCosts" numeric(12,2) NOT NULL DEFAULT 0,
        ADD COLUMN "dismantlingStartDate" date,
        ADD COLUMN "dismantlingEndDate" date
    `);
    await queryRunner.query(
      `UPDATE "donor_vehicles" SET "otherCosts" = "extraCosts"`,
    );

    await queryRunner.query(`
      CREATE TYPE "public"."donor_vehicles_status_enum_v2" AS ENUM (
        'purchased', 'waiting_for_dismantling', 'dismantling',
        'partially_dismantled', 'fully_dismantled', 'archived'
      )
    `);
    await queryRunner.query(
      `ALTER TABLE "donor_vehicles" ALTER COLUMN "status" DROP DEFAULT`,
    );
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles" ALTER COLUMN "status"
      TYPE "public"."donor_vehicles_status_enum_v2"
      USING (CASE "status"::text
        WHEN 'awaiting' THEN 'waiting_for_dismantling'
        WHEN 'dismantled' THEN 'fully_dismantled'
        WHEN 'closed' THEN 'archived'
        ELSE "status"::text
      END)::"public"."donor_vehicles_status_enum_v2"
    `);
    await queryRunner.query(`DROP TYPE "public"."donor_vehicles_status_enum"`);
    await queryRunner.query(`
      ALTER TYPE "public"."donor_vehicles_status_enum_v2"
      RENAME TO "donor_vehicles_status_enum"
    `);
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles" ALTER COLUMN "status" SET DEFAULT 'purchased'
    `);

    await queryRunner.query(`
      UPDATE "donor_vehicles" d SET "dismantlingStartDate" = COALESCE(
        (SELECT MIN(i."createdAt")::date FROM "items" i WHERE i."donorId" = d.id),
        d."updatedAt"::date
      )
      WHERE d."status" NOT IN ('purchased', 'waiting_for_dismantling')
    `);
    await queryRunner.query(`
      UPDATE "donor_vehicles" SET "dismantlingEndDate" = "updatedAt"::date
      WHERE "status" IN ('fully_dismantled', 'archived')
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_donor_vehicles_org_created"
      ON "donor_vehicles" ("organizationId", "createdAt")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_donor_vehicles_org_vin"
      ON "donor_vehicles" ("organizationId", "vin")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_donor_vehicles_org_vin"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_donor_vehicles_org_created"`,
    );

    await queryRunner.query(`
      CREATE TYPE "public"."donor_vehicles_status_enum_v1"
      AS ENUM ('awaiting', 'dismantling', 'dismantled', 'closed')
    `);
    await queryRunner.query(
      `ALTER TABLE "donor_vehicles" ALTER COLUMN "status" DROP DEFAULT`,
    );
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles" ALTER COLUMN "status"
      TYPE "public"."donor_vehicles_status_enum_v1"
      USING (CASE "status"::text
        WHEN 'purchased' THEN 'awaiting'
        WHEN 'waiting_for_dismantling' THEN 'awaiting'
        WHEN 'partially_dismantled' THEN 'dismantling'
        WHEN 'fully_dismantled' THEN 'dismantled'
        WHEN 'archived' THEN 'closed'
        ELSE "status"::text
      END)::"public"."donor_vehicles_status_enum_v1"
    `);
    await queryRunner.query(`DROP TYPE "public"."donor_vehicles_status_enum"`);
    await queryRunner.query(`
      ALTER TYPE "public"."donor_vehicles_status_enum_v1"
      RENAME TO "donor_vehicles_status_enum"
    `);
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles" ALTER COLUMN "status" SET DEFAULT 'awaiting'
    `);

    await queryRunner.query(`
      UPDATE "donor_vehicles"
      SET "extraCosts" = "deliveryCost" + "dismantlingCost" + "otherCosts"
    `);
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles"
        DROP COLUMN "dismantlingEndDate",
        DROP COLUMN "dismantlingStartDate",
        DROP COLUMN "otherCosts",
        DROP COLUMN "dismantlingCost",
        DROP COLUMN "deliveryCost",
        DROP COLUMN "drivetrain",
        DROP COLUMN "transmission",
        DROP COLUMN "engineVolume",
        DROP COLUMN "body",
        DROP COLUMN "generation"
    `);
  }
}
