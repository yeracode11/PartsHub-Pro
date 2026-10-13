import { MigrationInterface, QueryRunner } from 'typeorm';

export class ServiceReminders1772000000000 implements MigrationInterface {
  name = 'ServiceReminders1772000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "service_reminder_settings" (
        "organizationId" uuid NOT NULL,
        "enabled" boolean NOT NULL DEFAULT false,
        "daysBefore" integer NOT NULL DEFAULT 3,
        "connectionId" uuid,
        "templateStatus" character varying(32),
        "templateError" text,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_reminder_settings" PRIMARY KEY ("organizationId")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "service_reminder_log" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "vehicleId" integer NOT NULL,
        "customerId" integer,
        "dueDate" date NOT NULL,
        "status" character varying(16) NOT NULL,
        "messageId" character varying(128),
        "error" text,
        "attempts" integer NOT NULL DEFAULT 1,
        "lastAttemptAt" TIMESTAMP NOT NULL DEFAULT now(),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_reminder_log" PRIMARY KEY ("id"),
        CONSTRAINT "FK_service_reminder_log_vehicle" FOREIGN KEY ("vehicleId")
          REFERENCES "vehicles"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_service_reminder_log_due"
      ON "service_reminder_log" ("organizationId", "vehicleId", "dueDate")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "service_reminder_log"`);
    await queryRunner.query(`DROP TABLE "service_reminder_settings"`);
  }
}
