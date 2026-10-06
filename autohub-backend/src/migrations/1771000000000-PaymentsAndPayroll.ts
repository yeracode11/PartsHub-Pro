import { MigrationInterface, QueryRunner } from 'typeorm';

export class PaymentsAndPayroll1771000000000 implements MigrationInterface {
  name = 'PaymentsAndPayroll1771000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_payments" (
        "id" SERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "orderId" integer NOT NULL,
        "amount" numeric(10,2) NOT NULL,
        "method" varchar(20) NOT NULL,
        "createdByUserId" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_payments" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_payments_order" FOREIGN KEY ("orderId")
          REFERENCES "orders"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_order_payments_org_created"
      ON "order_payments" ("organizationId", "createdAt")
    `);
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN IF NOT EXISTS "payType" varchar(20) NOT NULL DEFAULT 'percent'
    `);
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN IF NOT EXISTS "payRate" numeric(10,2) NOT NULL DEFAULT 40
    `);
    await queryRunner.query(`
      ALTER TABLE "order_works"
      ADD COLUMN IF NOT EXISTS "doneAt" TIMESTAMP WITH TIME ZONE
    `);
    await queryRunner.query(`
      UPDATE "order_works"
      SET "doneAt" = "updatedAt"
      WHERE "done" = true AND "doneAt" IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "order_works" DROP COLUMN IF EXISTS "doneAt"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "payRate"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "payType"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "order_payments"`);
  }
}
