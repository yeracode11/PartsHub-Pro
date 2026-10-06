import { MigrationInterface, QueryRunner } from 'typeorm';

export class Schedule1770900000000 implements MigrationInterface {
  name = 'Schedule1770900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "service_posts" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "name" varchar(100) NOT NULL,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "isActive" boolean NOT NULL DEFAULT true,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_posts" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_service_posts_org"
      ON "service_posts" ("organizationId")
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "appointments" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "postId" integer NOT NULL,
        "customerId" integer,
        "vehicleId" integer,
        "masterId" uuid,
        "startsAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "endsAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "status" varchar(30) NOT NULL DEFAULT 'scheduled',
        "notes" text,
        "orderId" integer,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_appointments" PRIMARY KEY ("id"),
        CONSTRAINT "FK_appointments_post" FOREIGN KEY ("postId")
          REFERENCES "service_posts"("id"),
        CONSTRAINT "FK_appointments_master" FOREIGN KEY ("masterId")
          REFERENCES "users"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_appointments_order" FOREIGN KEY ("orderId")
          REFERENCES "orders"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_appointments_org_start"
      ON "appointments" ("organizationId", "startsAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "appointments"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "service_posts"`);
  }
}
