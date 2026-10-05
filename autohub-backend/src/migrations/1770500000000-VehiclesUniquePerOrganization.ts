import { MigrationInterface, QueryRunner } from 'typeorm';

export class VehiclesUniquePerOrganization1770500000000
  implements MigrationInterface
{
  name = 'VehiclesUniquePerOrganization1770500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "vehicles" DROP CONSTRAINT IF EXISTS "UQ_66ea96381a7a7ceb35c72f36625"`,
    );
    await queryRunner.query(
      `ALTER TABLE "vehicles" DROP CONSTRAINT IF EXISTS "UQ_8288ce015b69c5856cf54e07a67"`,
    );
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_vehicles_org_plate_active"
      ON "vehicles" ("organizationId", "plateNumber")
      WHERE "isActive" = true
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_vehicles_org_vin_active"
      ON "vehicles" ("organizationId", "vin")
      WHERE "isActive" = true AND "vin" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_vehicles_org_vin_active"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_vehicles_org_plate_active"`);
    await queryRunner.query(
      `ALTER TABLE "vehicles" ADD CONSTRAINT "UQ_8288ce015b69c5856cf54e07a67" UNIQUE ("vin")`,
    );
    await queryRunner.query(
      `ALTER TABLE "vehicles" ADD CONSTRAINT "UQ_66ea96381a7a7ceb35c72f36625" UNIQUE ("plateNumber")`,
    );
  }
}
