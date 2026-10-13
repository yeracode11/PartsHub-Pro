import { MigrationInterface, QueryRunner } from 'typeorm';

export class VehicleServiceRecords1771900000000 implements MigrationInterface {
  name = 'VehicleServiceRecords1771900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "vehicle_service_records" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "vehicleId" integer NOT NULL,
        "serviceDate" date NOT NULL,
        "mileage" integer NOT NULL,
        "description" text,
        "orderId" integer,
        "nextServiceMileage" integer,
        "nextServiceDate" date,
        "createdById" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_vehicle_service_records" PRIMARY KEY ("id"),
        CONSTRAINT "FK_vehicle_service_records_vehicle" FOREIGN KEY ("vehicleId")
          REFERENCES "vehicles"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_vehicle_service_records_vehicle"
      ON "vehicle_service_records" ("organizationId", "vehicleId", "serviceDate")
    `);
    // Уже записанное «последнее ТО» становится первой записью истории.
    await queryRunner.query(`
      INSERT INTO "vehicle_service_records"
        ("organizationId", "vehicleId", "serviceDate", "mileage",
         "nextServiceMileage", "nextServiceDate", "createdAt")
      SELECT "organizationId", "id", "lastServiceDate",
             COALESCE("lastServiceMileage", "currentMileage", 0),
             "nextServiceMileage", "nextServiceDate", now()
      FROM "vehicles"
      WHERE "lastServiceDate" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "vehicle_service_records"`);
  }
}
