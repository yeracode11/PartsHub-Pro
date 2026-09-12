import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPhoneToUsers1770200000000 implements MigrationInterface {
  name = 'AddPhoneToUsers1770200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "phone" character varying(20) NULL
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_users_phone" ON "users" ("phone")
      WHERE "phone" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_phone"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "phone"`);
  }
}
